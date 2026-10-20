// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

/// @title AISentinelHyperlaneOrigin
/// @notice Origin-side contract for AI Sentinel cross-chain intelligence messages.
/// @dev Emits structured intelligence events that Reactive Network can detect and route through Hyperlane.
contract HyperlaneOrigin {
    enum SignalType {
        GENERIC,
        AAVE_RISK,
        UNISWAP_RISK,
        WHALE_ACTIVITY,
        ORACLE_RISK,
        GOVERNANCE_RISK,
        PORTFOLIO_REBALANCE,
        EMERGENCY_PROTECTION
    }

    enum Urgency {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }

    struct IntelligenceSignal {
        SignalType signalType;
        Urgency urgency;
        uint256 riskScore;
        uint256 opportunityScore;
        uint256 timestamp;
        address source;
        bytes payload;
    }

    event Trigger(bytes message);

    event IntelligenceTriggered(
        SignalType indexed signalType,
        Urgency indexed urgency,
        uint256 riskScore,
        uint256 opportunityScore,
        address indexed source,
        bytes payload
    );

    event Received(
        uint32 indexed chain_id,
        address indexed sender,
        bytes message
    );

    address public owner;
    address public mailbox;

    uint256 public totalSignals;
    uint256 public criticalSignals;

    mapping(uint256 => IntelligenceSignal) public signals;

    constructor(address _mailbox) {
        owner = msg.sender;
        mailbox = _mailbox;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyMailbox() {
        require(msg.sender == mailbox, "Not authorized");
        _;
    }

    function trigger(bytes calldata message) external onlyOwner {
        emit Trigger(message);
    }

    function triggerIntelligenceSignal(
        SignalType signalType,
        Urgency urgency,
        uint256 riskScore,
        uint256 opportunityScore,
        bytes calldata payload
    ) external onlyOwner returns (uint256) {
        require(riskScore <= 100, "Invalid risk score");
        require(opportunityScore <= 100, "Invalid opportunity score");

        uint256 signalId = totalSignals;

        signals[signalId] = IntelligenceSignal({
            signalType: signalType,
            urgency: urgency,
            riskScore: riskScore,
            opportunityScore: opportunityScore,
            timestamp: block.timestamp,
            source: msg.sender,
            payload: payload
        });

        totalSignals++;

        if (urgency == Urgency.CRITICAL || riskScore >= 90) {
            criticalSignals++;
        }

        bytes memory encodedMessage = abi.encode(
            signalId,
            signalType,
            urgency,
            riskScore,
            opportunityScore,
            block.timestamp,
            msg.sender,
            payload
        );

        emit IntelligenceTriggered(
            signalType,
            urgency,
            riskScore,
            opportunityScore,
            msg.sender,
            payload
        );

        emit Trigger(encodedMessage);

        return signalId;
    }

    function triggerAaveRiskSignal(
        uint256 healthFactor,
        uint256 riskScore,
        bytes calldata payload
    ) external onlyOwner returns (uint256) {
        Urgency urgency = _classifyUrgency(riskScore);

        bytes memory enrichedPayload = abi.encode(
            "AAVE_RISK",
            healthFactor,
            payload
        );

        return triggerIntelligenceSignal(
            SignalType.AAVE_RISK,
            urgency,
            riskScore,
            0,
            enrichedPayload
        );
    }

    function triggerWhaleSignal(
        address whaleWallet,
        uint256 transferValue,
        uint256 riskScore,
        bytes calldata payload
    ) external onlyOwner returns (uint256) {
        Urgency urgency = _classifyUrgency(riskScore);

        bytes memory enrichedPayload = abi.encode(
            "WHALE_ACTIVITY",
            whaleWallet,
            transferValue,
            payload
        );

        return triggerIntelligenceSignal(
            SignalType.WHALE_ACTIVITY,
            urgency,
            riskScore,
            0,
            enrichedPayload
        );
    }

    function triggerOracleRiskSignal(
        address oracle,
        uint256 deviationScore,
        bytes calldata payload
    ) external onlyOwner returns (uint256) {
        Urgency urgency = _classifyUrgency(deviationScore);

        bytes memory enrichedPayload = abi.encode(
            "ORACLE_RISK",
            oracle,
            deviationScore,
            payload
        );

        return triggerIntelligenceSignal(
            SignalType.ORACLE_RISK,
            urgency,
            deviationScore,
            0,
            enrichedPayload
        );
    }

    function handle(
        uint32 chain_id,
        bytes32 sender,
        bytes calldata message
    ) external payable onlyMailbox {
        emit Received(chain_id, address(uint160(uint256(sender))), message);
    }

    function getSignal(uint256 signalId) external view returns (IntelligenceSignal memory) {
        require(signalId < totalSignals, "Signal does not exist");
        return signals[signalId];
    }

    function _classifyUrgency(uint256 riskScore) internal pure returns (Urgency) {
        if (riskScore >= 90) return Urgency.CRITICAL;
        if (riskScore >= 75) return Urgency.HIGH;
        if (riskScore >= 50) return Urgency.MEDIUM;
        return Urgency.LOW;
    }
}