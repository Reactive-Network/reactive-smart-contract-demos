// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../AbstractCallback.sol";

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

contract AutomatedPredictionMarket is AbstractCallback{

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
    uint256 public constant MAX_FEE_PERCENTAGE = 5; // 5% max fee

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
    event Voted(uint256 indexed proposalId, address voter, bool support, uint256 weight);
    event MultiSigVoted(uint256 indexed predictionId, address voter, bool support, uint256 resolutionIndex);

    constructor(address _callback_sender) AbstractCallback(_callback_sender) payable {}
    receive() external payable { }

    function initialize(
        uint256 _minBet,
        uint256 _feePercentage,
        uint256 _referralRewardPercentage,
        address[] memory _multiSigWallet,
        uint256 _requiredSignatures
    ) public {
        minBet = _minBet;
        if (_feePercentage > MAX_FEE_PERCENTAGE) revert FeeTooHigh();
        feePercentage = _feePercentage;
        referralRewardPercentage = _referralRewardPercentage;
        multiSigWallet = _multiSigWallet;
        requiredSignatures = _requiredSignatures;
    }

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
        
        predictions.push(Prediction({
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
        }));

        emit PredictionCreated(predictions.length - 1, _description, endTime);
    }

    function purchaseShares(uint256 _predictionId, uint256 _option) external payable {
        if (msg.value < minBet) revert BetAmountTooLow();
        Prediction storage prediction = predictions[_predictionId];
        if (block.timestamp >= prediction.bettingEndTime) revert BettingPeriodEnded();
        if (prediction.isResolved) revert PredictionAlreadyResolved();
        if (_option >= prediction.options.length) revert InvalidOption();

        uint256 fee = msg.value * feePercentage / 100;
        uint256 betAmount = msg.value - fee;

        uint256 shares = calculateShares(betAmount, prediction.optionShares[_option], prediction.totalShares);
        prediction.optionShares[_option] += shares;
        prediction.totalShares += betAmount;
        prediction.totalBetAmount += betAmount;
        userShares[_predictionId][msg.sender][_option] += shares;

        prediction.participants.push(msg.sender);

        if (referrals[msg.sender] != address(0)) {
            uint256 referralReward = fee * referralRewardPercentage / 100;
            payable(referrals[msg.sender]).transfer(referralReward);
        }

        emit SharesPurchased(_predictionId, msg.sender, _option, betAmount, shares);
    }

    function calculateShares(uint256 _amount, uint256 _currentShares, uint256 _totalShares) private pure returns (uint256) {
        if (_totalShares == 0) {
            return _amount;
        }
        return _amount * _currentShares / _totalShares;
    }

    function proposeResolution(uint256 _predictionId, bool _outcome) external payable{
        Prediction storage prediction = predictions[_predictionId];
        if (prediction.isResolved) revert PredictionAlreadyResolved();
        if (block.timestamp < prediction.endTime || block.timestamp >= prediction.resolutionEndTime) revert NotInResolutionPeriod();
        
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
            finalizeResolution(_predictionId, _resolutionIndex);
        }
    }

    function finalizeResolution(uint256 _predictionId, uint256 _resolutionIndex) private {
        Prediction storage prediction = predictions[_predictionId];
        Resolution storage selectedResolution = resolutions[_predictionId][_resolutionIndex];
        if (prediction.isResolved) revert PredictionAlreadyResolved();
        if (block.timestamp < prediction.resolutionEndTime) revert ResolutionPeriodNotEnded();

        bool outcome = selectedResolution.forStake > selectedResolution.againstStake;
        prediction.isResolved = true;
        prediction.outcome = outcome ? 1 : 0;
        selectedResolution.isResolved = true;

        // Distribute stakes
        for (uint256 i = 0; i < resolutions[_predictionId].length; i++) {
            Resolution storage resolution = resolutions[_predictionId][i];
            for (uint256 j = 0; j < resolution.stakers.length; j++) {
                address staker = resolution.stakers[j];
                uint256 stake = resolution.stakerVotes[staker];
                bool stakerOutcome = resolution.forStake > resolution.againstStake;

                if (i == _resolutionIndex) {
                    // Winner gets stake back plus 10% profit
                    uint256 reward = stake + (stake * 10 / 100);
                    payable(staker).transfer(reward);
                } else if (stakerOutcome == outcome) {
                    // Correct outcome but not selected, return stake
                    payable(staker).transfer(stake);
                } else {
                    // Incorrect outcome, pay 5% fee
                    uint256 penalty = stake * 5 / 100;
                    payable(staker).transfer(stake - penalty);
                }
            }
        }

        emit PredictionResolved(_predictionId, prediction.outcome);
    }

    function distributeWinnings(address /*sender*/,uint256 _predictionId) external{
        Prediction storage prediction = predictions[_predictionId];
        if (!prediction.isResolved) revert PredictionAlreadyResolved();
        if (prediction.lastDistributionIndex >= prediction.participants.length) revert("All winnings distributed");

        uint256 startIndex = prediction.lastDistributionIndex;
        uint256 endIndex = startIndex + DISTRIBUTION_BATCH_SIZE;
        if (endIndex > prediction.participants.length) {
            endIndex = prediction.participants.length;
        }

        for (uint256 i = startIndex; i < endIndex; i++) {
            address participant = prediction.participants[i];
            uint256 userSharesAmount = userShares[_predictionId][participant][prediction.outcome];
            if (userSharesAmount > 0) {
                uint256 reward = userSharesAmount * prediction.totalBetAmount / prediction.optionShares[prediction.outcome];
                userShares[_predictionId][participant][prediction.outcome] = 0;
                payable(participant).transfer(reward);
                emit RewardsClaimed(_predictionId, participant, reward);
            }
        }

        prediction.lastDistributionIndex = endIndex;
        emit WinningsDistributed(_predictionId, startIndex / DISTRIBUTION_BATCH_SIZE, endIndex - startIndex);
    }

    function setReferral(address _referrer) external {
        if (referrals[msg.sender] != address(0)) revert ReferralAlreadySet();
        if (_referrer == msg.sender) revert CannotReferSelf();
        referrals[msg.sender] = _referrer;
    }

    function isMultiSigWallet(address _address) public view returns (bool) {
        for (uint256 i = 0; i < multiSigWallet.length; i++) {
            if (multiSigWallet[i] == _address) {
                return true;
            }
        }
        return false;
    }
}