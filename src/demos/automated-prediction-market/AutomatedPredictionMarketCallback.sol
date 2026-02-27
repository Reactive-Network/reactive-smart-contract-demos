// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol";

// Custom errors
error FeeTooHigh();
error DurationMustBePositive();
error MinimumTwoOptionsRequired();
error BettingMustEndBeforePredictionEnds();
error BetAmountTooLow();
error BettingPeriodEnded();
error PredictionAlreadyResolved();
error InvalidOption();
error AlreadyProposed();
error NotInResolutionPeriod();
error NotAuthorized();
error InvalidResolutionIndex();
error ResolutionAlreadyFinalized();
error ResolutionPeriodNotEnded();
error ReferralAlreadySet();
error CannotReferSelf();

/**
 * @title AutomatedPredictionMarket
 * @notice Manages prediction market creation, share purchases, resolution, and winnings distribution
 * @dev Deployed on Ethereum Sepolia; winnings distribution is triggered by the Reactive contract
 */
contract AutomatedPredictionMarket is AbstractCallback {
    struct Prediction {
        string description;
        uint256 endTime;
        uint256[] options;
        uint256[] optionShares;
        uint256 totalShares;
        bool isResolved;
        uint256 outcome;
        uint256 bettingEndTime;
        uint256 resolutionEndTime;
        address[] participants;
        uint256 lastDistributionIndex;
        uint256 totalBetAmount;
    }

    struct Resolution {
        uint256 forStake;
        uint256 againstStake;
        mapping(address => uint256) stakerVotes;
        address[] stakers;
        bool isResolved;
        uint256 approvalCount;
        address proposer;
    }

    Prediction[] public predictions;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public userShares;
    mapping(uint256 => Resolution[]) public resolutions;

    uint256 public minBet;
    uint256 public feePercentage;
    uint256 public constant MAX_FEE_PERCENTAGE = 5;

    mapping(address => address) public referrals;
    uint256 public referralRewardPercentage;

    address[] public multiSigWallet;
    uint256 public requiredSignatures;

    uint256 public constant DISTRIBUTION_BATCH_SIZE = 100;

    event PredictionCreated(uint256 indexed predictionId, string description, uint256 endTime);
    event SharesPurchased(uint256 indexed predictionId, address user, uint256 option, uint256 amount, uint256 shares);
    event ResolutionProposed(uint256 indexed predictionId, address proposer, bool outcome, uint256 stake);
    event PredictionResolved(uint256 indexed predictionId, uint256 outcome);
    event RewardsClaimed(uint256 indexed predictionId, address user, uint256 reward);
    event WinningsDistributed(uint256 indexed predictionId, uint256 batchIndex, uint256 batchSize);
    event MultiSigVoted(uint256 indexed predictionId, address voter, bool support, uint256 resolutionIndex);

    constructor(address _callbackSender) payable AbstractCallback(_callbackSender) {}

    function initialize(
        uint256 _minBet,
        uint256 _feePercentage,
        uint256 _referralRewardPercentage,
        address[] memory _multiSigWallet,
        uint256 _requiredSignatures
    ) external {
        if (_feePercentage > MAX_FEE_PERCENTAGE) revert FeeTooHigh();
        minBet = _minBet;
        feePercentage = _feePercentage;
        referralRewardPercentage = _referralRewardPercentage;
        multiSigWallet = _multiSigWallet;
        requiredSignatures = _requiredSignatures;
    }

    /**
     * @notice Creates a new prediction market
     * @param _description Human-readable description of the prediction
     * @param _duration Total duration of the prediction in seconds
     * @param _options Array of option identifiers (e.g. [1, 2] for Yes/No)
     * @param _bettingDuration Duration during which shares can be purchased
     * @param _resolutionDuration Duration after endTime during which resolution can be proposed
     */
    function createPrediction(
        string memory _description,
        uint256 _duration,
        uint256[] memory _options,
        uint256 _bettingDuration,
        uint256 _resolutionDuration
    ) external {
        if (_duration == 0) revert DurationMustBePositive();
        if (_options.length <= 1) revert MinimumTwoOptionsRequired();

        uint256 endTime = block.timestamp + _duration;
        uint256 bettingEndTime = block.timestamp + _bettingDuration;
        uint256 resolutionEndTime = endTime + _resolutionDuration;

        if (bettingEndTime >= endTime) revert BettingMustEndBeforePredictionEnds();

        uint256[] memory optionShares = new uint256[](_options.length);

        predictions.push(
            Prediction({
                description: _description,
                endTime: endTime,
                options: _options,
                optionShares: optionShares,
                totalShares: 0,
                isResolved: false,
                outcome: 0,
                bettingEndTime: bettingEndTime,
                resolutionEndTime: resolutionEndTime,
                participants: new address[](0),
                lastDistributionIndex: 0,
                totalBetAmount: 0
            })
        );

        emit PredictionCreated(predictions.length - 1, _description, endTime);
    }

    /**
     * @notice Purchase shares for a prediction option
     * @param _predictionId ID of the prediction
     * @param _option Index of the option to bet on
     */
    function purchaseShares(uint256 _predictionId, uint256 _option) external payable {
        if (msg.value < minBet) revert BetAmountTooLow();

        Prediction storage prediction = predictions[_predictionId];

        if (block.timestamp >= prediction.bettingEndTime) revert BettingPeriodEnded();
        if (prediction.isResolved) revert PredictionAlreadyResolved();
        if (_option >= prediction.options.length) revert InvalidOption();

        uint256 fee = msg.value * feePercentage / 100;
        uint256 betAmount = msg.value - fee;

        uint256 shares = _calculateShares(betAmount, prediction.optionShares[_option], prediction.totalShares);
        prediction.optionShares[_option] += shares;
        prediction.totalShares += betAmount;
        prediction.totalBetAmount += betAmount;
        userShares[_predictionId][msg.sender][_option] += shares;
        prediction.participants.push(msg.sender);

        if (referrals[msg.sender] != address(0)) {
            uint256 referralReward = fee * referralRewardPercentage / 100;
            (bool success,) = payable(referrals[msg.sender]).call{value: referralReward}("");
            require(success, "Referral reward transfer failed");
        }

        emit SharesPurchased(_predictionId, msg.sender, _option, betAmount, shares);
    }

    /**
     * @notice Propose a resolution outcome for a prediction
     * @param _predictionId ID of the prediction to resolve
     * @param _outcome True for option index 1 winning, false for option index 0
     */
    function proposeResolution(uint256 _predictionId, bool _outcome) external payable {
        Prediction storage prediction = predictions[_predictionId];

        if (prediction.isResolved) revert PredictionAlreadyResolved();
        if (block.timestamp < prediction.endTime || block.timestamp >= prediction.resolutionEndTime) {
            revert NotInResolutionPeriod();
        }

        Resolution storage resolution = resolutions[_predictionId].push();
        if (resolution.stakerVotes[msg.sender] != 0) revert AlreadyProposed();

        if (_outcome) {
            resolution.forStake = msg.value;
        } else {
            resolution.againstStake = msg.value;
        }

        resolution.stakerVotes[msg.sender] = msg.value;
        resolution.stakers.push(msg.sender);
        resolution.proposer = msg.sender;

        emit ResolutionProposed(_predictionId, msg.sender, _outcome, msg.value);
    }

    /**
     * @notice MultiSig holders vote on a proposed resolution
     * @param _predictionId ID of the prediction
     * @param _resolutionIndex Index of the resolution proposal to vote on
     * @param _support True to support the resolution
     */
    function voteOnResolution(uint256 _predictionId, uint256 _resolutionIndex, bool _support) external {
        if (!isMultiSigWallet(msg.sender)) revert NotAuthorized();
        if (_resolutionIndex >= resolutions[_predictionId].length) revert InvalidResolutionIndex();

        Resolution storage resolution = resolutions[_predictionId][_resolutionIndex];
        if (resolution.isResolved) revert ResolutionAlreadyFinalized();

        if (_support) {
            resolution.approvalCount++;
        }

        emit MultiSigVoted(_predictionId, msg.sender, _support, _resolutionIndex);

        if (resolution.approvalCount >= requiredSignatures) {
            _finalizeResolution(_predictionId, _resolutionIndex);
        }
    }

    /**
     * @notice Distributes winnings to participants in batches (triggered by Reactive Network)
     * @param _predictionId ID of the resolved prediction
     */
    function distributeWinnings(
        address, /*sender*/
        uint256 _predictionId
    )
        external
        authorizedSenderOnly
    {
        Prediction storage prediction = predictions[_predictionId];

        if (!prediction.isResolved) revert PredictionAlreadyResolved();
        require(prediction.lastDistributionIndex < prediction.participants.length, "All winnings distributed");

        uint256 startIndex = prediction.lastDistributionIndex;
        uint256 endIndex = startIndex + DISTRIBUTION_BATCH_SIZE;

        if (endIndex > prediction.participants.length) {
            endIndex = prediction.participants.length;
        }

        for (uint256 i = startIndex; i < endIndex; i++) {
            address participant = prediction.participants[i];
            uint256 userSharesAmount = userShares[_predictionId][participant][prediction.outcome];

            if (userSharesAmount > 0) {
                uint256 reward =
                    userSharesAmount * prediction.totalBetAmount / prediction.optionShares[prediction.outcome];
                userShares[_predictionId][participant][prediction.outcome] = 0;
                (bool success,) = payable(participant).call{value: reward}("");
                require(success, "Winnings transfer failed");
                emit RewardsClaimed(_predictionId, participant, reward);
            }
        }

        prediction.lastDistributionIndex = endIndex;
        emit WinningsDistributed(_predictionId, startIndex / DISTRIBUTION_BATCH_SIZE, endIndex - startIndex);
    }

    /**
     * @notice Set a referrer for the caller
     * @param _referrer Address of the referrer
     */
    function setReferral(address _referrer) external {
        if (referrals[msg.sender] != address(0)) revert ReferralAlreadySet();
        if (_referrer == msg.sender) revert CannotReferSelf();
        referrals[msg.sender] = _referrer;
    }

    /**
     * @notice Check if an address is a multisig wallet holder
     */
    function isMultiSigWallet(address _address) public view returns (bool) {
        for (uint256 i = 0; i < multiSigWallet.length; i++) {
            if (multiSigWallet[i] == _address) {
                return true;
            }
        }
        return false;
    }

    // Internal helpers

    function _calculateShares(uint256 _amount, uint256 _currentShares, uint256 _totalShares)
        private
        pure
        returns (uint256)
    {
        if (_totalShares == 0) {
            return _amount;
        }
        return _amount * _currentShares / _totalShares;
    }

    function _finalizeResolution(uint256 _predictionId, uint256 _resolutionIndex) private {
        Prediction storage prediction = predictions[_predictionId];
        Resolution storage selectedResolution = resolutions[_predictionId][_resolutionIndex];

        if (prediction.isResolved) revert PredictionAlreadyResolved();
        if (block.timestamp < prediction.resolutionEndTime) revert ResolutionPeriodNotEnded();

        bool outcome = selectedResolution.forStake > selectedResolution.againstStake;
        prediction.isResolved = true;
        prediction.outcome = outcome ? 1 : 0;
        selectedResolution.isResolved = true;

        // Distribute proposer stakes
        for (uint256 i = 0; i < resolutions[_predictionId].length; i++) {
            Resolution storage resolution = resolutions[_predictionId][i];
            for (uint256 j = 0; j < resolution.stakers.length; j++) {
                address staker = resolution.stakers[j];
                uint256 stake = resolution.stakerVotes[staker];
                bool stakerOutcome = resolution.forStake > resolution.againstStake;

                if (i == _resolutionIndex) {
                    // Winning proposer gets stake back + 10% bonus
                    uint256 reward = stake + (stake * 10 / 100);
                    (bool success,) = payable(staker).call{value: reward}("");
                    require(success, "Stake reward transfer failed");
                } else if (stakerOutcome == outcome) {
                    // Correct outcome but not selected resolution — return stake
                    (bool success,) = payable(staker).call{value: stake}("");
                    require(success, "Stake return transfer failed");
                } else {
                    // Incorrect outcome — 5% penalty
                    uint256 penalty = stake * 5 / 100;
                    (bool success,) = payable(staker).call{value: stake - penalty}("");
                    require(success, "Penalty stake transfer failed");
                }
            }
        }

        emit PredictionResolved(_predictionId, prediction.outcome);
    }
}
