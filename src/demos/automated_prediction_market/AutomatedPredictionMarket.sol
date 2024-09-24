// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract AutomatedPredictionMarket is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, ERC20Upgradeable {

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

    struct GovernanceProposal {
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 endTime;
        bool executed;
    }

    Prediction[] public predictions;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public userShares;
    mapping(uint256 => Resolution[]) public resolutions;
    GovernanceProposal[] public governanceProposals;

    uint256 public minBet;
    uint256 public feePercentage;
    uint256 public constant MAX_FEE_PERCENTAGE = 5; // 5% max fee
    uint256 public governanceThreshold;

    mapping(address => uint256) public governanceTokens;
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
    event GovernanceProposalCreated(uint256 indexed proposalId, string description, uint256 endTime);
    event Voted(uint256 indexed proposalId, address voter, bool support, uint256 weight);
    event MultiSigVoted(uint256 indexed predictionId, address voter, bool support, uint256 resolutionIndex);

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 _minBet,
        uint256 _feePercentage,
        uint256 _governanceThreshold,
        uint256 _referralRewardPercentage,
        address[] memory _multiSigWallet,
        uint256 _requiredSignatures
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
        __ERC20_init(name_, symbol_);

        minBet = _minBet;
        require(_feePercentage <= MAX_FEE_PERCENTAGE, "Fee too high");
        feePercentage = _feePercentage;
        governanceThreshold = _governanceThreshold;
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
    ) external onlyOwner whenNotPaused {
        require(_duration > 0, "Duration must be positive");
        require(_options.length > 1, "Must have at least two options");
        uint256 endTime = block.timestamp + _duration;
        uint256 bettingEndTime = block.timestamp + _bettingDuration;
        uint256 resolutionEndTime = endTime + _resolutionDuration;
        require(bettingEndTime < endTime, "Betting must end before prediction ends");

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

    function purchaseShares(uint256 _predictionId, uint256 _option) external payable nonReentrant whenNotPaused {
        require(msg.value >= minBet, "Bet amount too low");
        Prediction storage prediction = predictions[_predictionId];
        require(block.timestamp < prediction.bettingEndTime, "Betting period has ended");
        require(!prediction.isResolved, "Prediction already resolved");
        require(_option < prediction.options.length, "Invalid option");

        uint256 fee = msg.value * feePercentage / 100;
        uint256 betAmount = msg.value - fee;

        uint256 shares = calculateShares(betAmount, prediction.optionShares[_option], prediction.totalShares);
        prediction.optionShares[_option] += shares;
        prediction.totalShares += betAmount;
        prediction.totalBetAmount += betAmount;
        userShares[_predictionId][msg.sender][_option] += shares;

        _mint(msg.sender, shares);
        governanceTokens[msg.sender] += shares;

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

    function proposeResolution(uint256 _predictionId, bool _outcome) external payable whenNotPaused {
        Prediction storage prediction = predictions[_predictionId];
        require(!prediction.isResolved, "Prediction already resolved");
        require(block.timestamp >= prediction.endTime && block.timestamp < prediction.resolutionEndTime, "Not in resolution period");
        
        Resolution storage resolution = resolutions[_predictionId].push();
        require(resolution.stakerVotes[msg.sender] == 0, "Already proposed");

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
        require(isMultiSigWallet(msg.sender), "Not authorized");
        require(_resolutionIndex < resolutions[_predictionId].length, "Invalid resolution index");
        Resolution storage resolution = resolutions[_predictionId][_resolutionIndex];
        require(!resolution.isResolved, "Resolution already finalized");

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
        require(!prediction.isResolved, "Prediction already resolved");
        require(block.timestamp >= prediction.resolutionEndTime, "Resolution period not ended");

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
        //0xe0d11dcca65d89777e74a05aabfc99281a4c018644b33af1b397a7dbf5e2911b
        //ye cheez emit hogi toh distributewinnings function call hoga
    }

    function distributeWinnings(address,uint256 _predictionId) external nonReentrant {
        Prediction storage prediction = predictions[_predictionId];
        require(prediction.isResolved, "Prediction not resolved yet");
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
                uint256 reward = userSharesAmount * prediction.totalBetAmount / prediction.optionShares[prediction.outcome];
                userShares[_predictionId][participant][prediction.outcome] = 0;
                _burn(participant, userSharesAmount);
                payable(participant).transfer(reward);
                emit RewardsClaimed(_predictionId, participant, reward);
            }
        }

        prediction.lastDistributionIndex = endIndex;
        emit WinningsDistributed(_predictionId, startIndex / DISTRIBUTION_BATCH_SIZE, endIndex - startIndex);
    }

    function setReferral(address _referrer) external {
        require(referrals[msg.sender] == address(0), "Referral already set");
        require(_referrer != msg.sender, "Cannot refer yourself");
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

    function createGovernanceProposal(string memory _description, uint256 _duration) external {
        require(governanceTokens[msg.sender] >= governanceThreshold, "Not enough governance tokens");
        
        governanceProposals.push(GovernanceProposal({
            description: _description,
            forVotes: 0,
            againstVotes: 0,
            endTime: block.timestamp + _duration,
            executed: false
        }));

        emit GovernanceProposalCreated(governanceProposals.length - 1, _description, block.timestamp + _duration);
    }

    function vote(uint256 _proposalId, bool _support) external {
        require(_proposalId < governanceProposals.length, "Invalid proposal ID");
        GovernanceProposal storage proposal = governanceProposals[_proposalId];
        require(block.timestamp < proposal.endTime, "Voting period has ended");
        require(!proposal.executed, "Proposal already executed");

        uint256 weight = governanceTokens[msg.sender];
        require(weight > 0, "No voting power");

        if (_support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        emit Voted(_proposalId, msg.sender, _support, weight);
    }

    function getGovernanceTokens(address _user) external view returns (uint256) {
        return governanceTokens[_user];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}