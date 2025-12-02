// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import "../../../lib/reactive-lib/src/interfaces/IReactive.sol";
import "../../../lib/reactive-lib/src/abstract-base/AbstractPausableReactive.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PersonalAaveProtectionReactive
 * @notice Personal reactive smart contract for monitoring Aave liquidation protection
 * @dev Each user deploys their own instance paired with PersonalAaveProtectionCallback
 */
contract AaveProtectionDemoReactive is IReactive, AbstractPausableReactive {
    // Events
    event ConfigTracked(uint256 indexed configId);

    event ConfigUntracked(uint256 indexed configId);

    event ProtectionCheckTriggered(uint256 timestamp, uint256 blockNumber);

    event ProtectionCycleCompleted(uint256 timestamp);

    event ProcessingError(string reason, uint256 configId);

    // Constants
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant REACTIVE_CHAIN_ID = 5318007; // Lasna network chain ID
    uint256 private constant PROTECTION_CONFIGURED_TOPIC_0 =
        0x0379034bb39e80198ee227a7ca9971c0907bea154e437c678febe3f73a241bb0; // keccak256("ProtectionConfigured(uint256,uint8,uint256,uint256,address,address)")
    uint256 private constant PROTECTION_CANCELLED_TOPIC_0 =
        0xcf54734705fd889f6c3dd58ec1a558452d5cd3a3c5ef048ee5b5d925418b90db; // keccak256("ProtectionCancelled(uint256)")
    uint256 private constant PROTECTION_EXECUTED_TOPIC_0 =
        0x9a3c1f530d04162bf90017397efe9a9311e694c35705e3794d59287a95b0e8fe; // keccak256("ProtectionExecuted(uint256,string,address,uint256,uint256,uint256)")
    uint256 private constant PROTECTION_PAUSED_TOPIC_0 =
        0xee6234a3449f904f79d68953452c2b89497ebd146a8bc7ae5b0b4e8f3778a371; // keccak256("ProtectionPaused(uint256)")
    uint256 private constant PROTECTION_RESUMED_TOPIC_0 =
        0x4f84709bd4231f3fd9f66fe6df31a6590e47b2dbb73bd6a1e74d0f3d35474b02; // keccak256("ProtectionResumed(uint256)")
    uint256 private constant PROTECTION_CYCLE_COMPLETED_TOPIC_0 =
        0xb2a1984478c1064cb30b6e5bd7410ed80e897a5a51f65a9c4a826d92ba5a3492; // keccak256("ProtectionCycleCompleted(uint256,uint256,uint256)")
    uint64 private constant CALLBACK_GAS_LIMIT = 2000000;

    // Protection status enum (mirrors the callback contract)
    enum ProtectionStatus {
        Active,
        Paused,
        Cancelled
    }

    // Config tracking struct
    struct TrackedConfig {
        uint256 id;
        uint256 healthFactorThreshold;
        ProtectionStatus status;
        uint256 lastTriggeredAt;
        uint8 triggerCount;
    }

    address public immutable protectionCallback;
    uint256 public immutable cronTopic;

    bool private processingActive;

    // Config tracking
    mapping(uint256 => TrackedConfig) public trackedConfigs;
    uint256[] public configIds; // Track all config IDs for easy enumeration

    // Constants for retry logic
    uint256 private constant TRIGGER_COOLDOWN = 300; // 5 minutes between triggers
    uint8 private constant MAX_TRIGGER_ATTEMPTS = 5;

    constructor(address _owner, address _protectionCallback, uint256 _cronTopic) payable {
        owner = _owner;
        protectionCallback = _protectionCallback;
        cronTopic = _cronTopic;
        processingActive = false;

        if (!vm) {
            // Subscribe to CRON events for periodic monitoring
            service.subscribe(
                block.chainid, address(service), cronTopic, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
            );

            // Subscribe to protection lifecycle events from the personal callback contract
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                protectionCallback,
                PROTECTION_CONFIGURED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            service.subscribe(
                SEPOLIA_CHAIN_ID,
                protectionCallback,
                PROTECTION_CANCELLED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            service.subscribe(
                SEPOLIA_CHAIN_ID,
                protectionCallback,
                PROTECTION_EXECUTED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            service.subscribe(
                SEPOLIA_CHAIN_ID,
                protectionCallback,
                PROTECTION_PAUSED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            service.subscribe(
                SEPOLIA_CHAIN_ID,
                protectionCallback,
                PROTECTION_RESUMED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            // Subscribe to ProtectionCycleCompleted events from the callback contract
            // This event is ALWAYS emitted, ensuring the processing flag gets reset
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                protectionCallback,
                PROTECTION_CYCLE_COMPLETED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    // Main reaction function
    function react(LogRecord calldata log) external vmOnly {
        if (log.topic_0 == cronTopic) {
            // CRON event - trigger protection check for all active configs
            // NOTE: We don't check health factors here because this contract
            // runs on LASNA and has no access to Aave data on Sepolia
            if (processingActive) {
                return; // Already processing, skip this cycle
            }

            // Simply trigger the callback - let Sepolia contract do all the Aave checks
            bytes memory payload = abi.encodeWithSignature(
                "checkAndProtectPositions(address)",
                address(0) // sender (not used in callback)
            );

            processingActive = true;

            emit ProtectionCheckTriggered(block.timestamp, block.number);
            emit Callback(SEPOLIA_CHAIN_ID, protectionCallback, CALLBACK_GAS_LIMIT, payload);
        } else if (log._contract == protectionCallback && log.topic_0 == PROTECTION_CYCLE_COMPLETED_TOPIC_0) {
            // ProtectionCycleCompleted event from callback contract on Sepolia
            // This event is ALWAYS emitted regardless of whether any protections were executed
            // This ensures the processing flag gets reset and the system continues working
            processingActive = false;
            emit ProtectionCycleCompleted(block.timestamp);
        } else if (log._contract == protectionCallback) {
            _processProtectionEvent(log);
        }
    }

    // Process protection lifecycle events
    function _processProtectionEvent(LogRecord calldata log) internal {
        if (log.topic_0 == PROTECTION_CONFIGURED_TOPIC_0) {
            _processConfigCreated(log);
        } else if (log.topic_0 == PROTECTION_CANCELLED_TOPIC_0) {
            _processConfigCancelled(log);
        } else if (log.topic_0 == PROTECTION_EXECUTED_TOPIC_0) {
            _processConfigExecuted(log);
        } else if (log.topic_0 == PROTECTION_PAUSED_TOPIC_0) {
            _processConfigPaused(log);
        } else if (log.topic_0 == PROTECTION_RESUMED_TOPIC_0) {
            _processConfigResumed(log);
        }
    }

    // Process config creation
    function _processConfigCreated(LogRecord calldata log) internal {
        // Extract data from event topics
        uint256 configId = uint256(log.topic_1);

        // Decode additional data from log.data
        (, uint256 healthFactorThreshold,,,) = abi.decode(log.data, (uint8, uint256, uint256, address, address));

        // Track the config
        trackedConfigs[configId] = TrackedConfig({
            id: configId,
            healthFactorThreshold: healthFactorThreshold,
            status: ProtectionStatus.Active,
            lastTriggeredAt: 0,
            triggerCount: 0
        });

        // Add to config list
        configIds.push(configId);

        emit ConfigTracked(configId);
    }

    // Process config cancellation
    function _processConfigCancelled(LogRecord calldata log) internal {
        uint256 configId = uint256(log.topic_1);

        if (trackedConfigs[configId].id == configId) {
            trackedConfigs[configId].status = ProtectionStatus.Cancelled;
            emit ConfigUntracked(configId);
        }
    }

    // Process config execution
    function _processConfigExecuted(LogRecord calldata log) internal {
        uint256 configId = uint256(log.topic_1);

        if (trackedConfigs[configId].id == configId) {
            // Reset trigger tracking after successful execution
            trackedConfigs[configId].lastTriggeredAt = 0;
            trackedConfigs[configId].triggerCount = 0;
        }
    }

    // Process config pause
    function _processConfigPaused(LogRecord calldata log) internal {
        uint256 configId = uint256(log.topic_1);

        if (trackedConfigs[configId].id == configId) {
            trackedConfigs[configId].status = ProtectionStatus.Paused;
        }
    }

    // Process config resume
    function _processConfigResumed(LogRecord calldata log) internal {
        uint256 configId = uint256(log.topic_1);

        if (trackedConfigs[configId].id == configId) {
            trackedConfigs[configId].status = ProtectionStatus.Active;
        }
    }

    // View functions
    function getActiveConfigs() external view returns (uint256[] memory) {
        uint256 activeCount = 0;

        // Count active configs
        for (uint256 i = 0; i < configIds.length; i++) {
            uint256 configId = configIds[i];
            if (trackedConfigs[configId].status == ProtectionStatus.Active) {
                activeCount++;
            }
        }

        // Build active configs array
        uint256[] memory activeConfigs = new uint256[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < configIds.length; i++) {
            uint256 configId = configIds[i];
            if (trackedConfigs[configId].status == ProtectionStatus.Active) {
                activeConfigs[index] = configId;
                index++;
            }
        }

        return activeConfigs;
    }

    function getPausableSubscriptions() internal view override returns (Subscription[] memory) {
        Subscription[] memory result = new Subscription[](1);
        result[0] =
            Subscription(block.chainid, address(service), cronTopic, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
        return result;
    }

    // View functions to check current state
    function isProcessingActive() external view returns (bool) {
        return processingActive;
    }

    function getProtectionCallback() external view returns (address) {
        return protectionCallback;
    }

    function getCronTopic() external view returns (uint256) {
        return cronTopic;
    }

    // Reset processing flag manually if needed (emergency function)
    function resetProcessingFlag() external onlyOwner {
        processingActive = false;
    }

    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient address");
        SafeERC20.safeTransfer(IERC20(token), to, amount);
    }

    function rescueAllERC20(address token, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient address");
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to rescue");
        SafeERC20.safeTransfer(IERC20(token), to, balance);
    }

    // Emergency withdrawal functions - only deployer can call
    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient ETH balance");

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function withdrawAllETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");

        (bool success,) = payable(msg.sender).call{value: balance}("");
        require(success, "ETH transfer failed");
    }
}
