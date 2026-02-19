// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../../lib/reactive-lib/src/interfaces/IReactive.sol";
import "../../../lib/reactive-lib/src/abstract-base/AbstractPausableReactive.sol";
import "../../../lib/reactive-lib/src/interfaces/ISystemContract.sol";

/// @title LoopingRSC - Reactive Smart Contract for automated leverage looping
/// @notice Listens to Deposited/LoopStepExecuted events and triggers leverage steps based on Health Factor
/// @dev Fixed: No hardcoded prices, dynamic decimal handling, no slippage calculation
contract LoopingRSC is AbstractPausableReactive {
    // Chain & gas config
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint64 private constant CALLBACK_GAS_LIMIT = 2000000;

    // Strategy parameters - Health Factor based
    uint256 private constant TARGET_HEALTH_FACTOR = 15e17; // 1.5 (18 decimals)
    uint256 private constant MIN_HEALTH_FACTOR = 12e17; // 1.2 minimum safety threshold
    uint256 private constant MAX_ITERATIONS = 5;

    // Borrow constraints (in USD, 18 decimals)
    uint256 private constant MIN_BORROW_USD = 1e17; // $0.1 minimum (low for testnet)
    uint256 private constant MAX_BORROW_USD = 500e18; // $500 cap per iteration

    // Conservative leverage factors (basis points)
    uint256 private constant INITIAL_LEVERAGE_FACTOR = 4000; // 40% of collateral value
    uint256 private constant SUBSEQUENT_LEVERAGE_FACTOR = 5500; // 55% of new collateral

    // Event topic hashes
    // cast keccak "Deposited(address,address,uint256,uint256,uint256,uint8)"
    uint256 private constant TOPIC_DEPOSITED =
        0xf6f7eb594d038f473e5f6b9543f860b51b8c17d68104222832ff1d98f7efb30c;

    // cast keccak "LoopStepExecuted(uint256,uint256,uint256,uint256,uint256,uint8)"
    uint256 private constant TOPIC_LOOP_STEP =
        0x7e802efb14392b5b75aedfd4ccfb6ac74a5f5a30ebce7a23a4cf8ec0713aa963;

    // Sepolia contract addresses
    address public leverageAccount;
    address public weth;
    address public borrowAsset;
    uint8 public borrowAssetDecimals;

    // Events
    event LoopInitiated(uint256 borrowAmountUSD, uint256 initialHealthFactor);
    event LoopContinued(
        uint256 borrowAmountUSD,
        uint256 currentHealthFactor,
        uint256 iteration
    );
    event LoopCompleted(uint256 finalHealthFactor, uint256 totalIterations);
    event LoopStopped(string reason, uint256 healthFactor, uint256 iteration);

    constructor(
        address _service,
        address _leverageAccount,
        address _weth,
        address _borrowAsset,
        uint8 _borrowAssetDecimals
    ) payable {
        service = ISystemContract(payable(_service));
        owner = msg.sender;
        leverageAccount = _leverageAccount;
        weth = _weth;
        borrowAsset = _borrowAsset;
        borrowAssetDecimals = _borrowAssetDecimals;

        if (!vm) {
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                leverageAccount,
                TOPIC_DEPOSITED,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                leverageAccount,
                TOPIC_LOOP_STEP,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    /// @notice Main entry point - called by Reactive Network when subscribed events fire
    function react(LogRecord calldata log) external vmOnly {
        if (
            log.chain_id != SEPOLIA_CHAIN_ID || log._contract != leverageAccount
        ) {
            return;
        }

        if (log.topic_0 == TOPIC_DEPOSITED) {
            _handleDeposited(log.data);
        } else if (log.topic_0 == TOPIC_LOOP_STEP) {
            _handleLoopStep(log.data);
        }
    }

    /// @dev Handle initial deposit - start looping if health factor allows
    /// @param data ABI encoded (non-indexed only): (uint256 amount, uint256 valueInUSD, uint256 healthFactor, uint8 tokenDecimals)
    /// @dev Note: `user` and `token` are indexed params and live in log topics, not in data
    function _handleDeposited(bytes calldata data) internal {
        (, uint256 valueInUSD, uint256 healthFactor, ) = abi.decode(
            data,
            (uint256, uint256, uint256, uint8)
        );

        // Safety check: don't loop if we're already leveraged or have low health factor
        if (
            healthFactor < TARGET_HEALTH_FACTOR &&
            healthFactor != type(uint256).max
        ) {
            emit LoopStopped("Health factor below target", healthFactor, 0);
            return;
        }

        // Calculate safe borrow amount using health factor-based approach
        // For first iteration, use conservative 40% of collateral value
        uint256 borrowAmountUSD = (valueInUSD * INITIAL_LEVERAGE_FACTOR) /
            10000;

        // Clamp to min/max bounds
        borrowAmountUSD = _clampBorrowUSD(borrowAmountUSD);

        if (borrowAmountUSD == 0) {
            emit LoopStopped("Borrow amount below minimum", healthFactor, 0);
            return;
        }

        emit LoopInitiated(borrowAmountUSD, healthFactor);

        // Send callback using stored borrow asset decimals
        _sendCallback(borrowAmountUSD, 1, borrowAssetDecimals);
    }

    /// @dev Handle loop step completion - continue if health factor allows
    /// @param data ABI encoded: (uint256 borrowed, uint256 receivedCollateral, uint256 newCollateralValueUSD, uint256 healthFactor, uint256 iterationId, uint8 borrowAssetDecimals)
    function _handleLoopStep(bytes calldata data) internal {
        (
            ,
            ,
            uint256 newCollateralValueUSD,
            uint256 healthFactor,
            uint256 iterationId,
            uint8 eventBorrowDecimals
        ) = abi.decode(
                data,
                (uint256, uint256, uint256, uint256, uint256, uint8)
            );

        // Stop conditions (check strictest first)
        if (iterationId >= MAX_ITERATIONS) {
            emit LoopCompleted(healthFactor, iterationId);
            return;
        }

        if (healthFactor <= MIN_HEALTH_FACTOR) {
            emit LoopStopped(
                "Health factor too low",
                healthFactor,
                iterationId
            );
            return;
        }

        if (healthFactor <= TARGET_HEALTH_FACTOR) {
            emit LoopCompleted(healthFactor, iterationId);
            return;
        }

        // Calculate next borrow using REAL USD value from oracle (fixes Problem A)
        uint256 nextBorrowUSD = (newCollateralValueUSD *
            SUBSEQUENT_LEVERAGE_FACTOR) / 10000;

        nextBorrowUSD = _clampBorrowUSD(nextBorrowUSD);

        if (nextBorrowUSD == 0) {
            emit LoopCompleted(healthFactor, iterationId);
            return;
        }

        emit LoopContinued(nextBorrowUSD, healthFactor, iterationId);

        // Pass the actual decimals from the event
        _sendCallback(nextBorrowUSD, iterationId + 1, eventBorrowDecimals);
    }

    /// @dev Clamp borrow amount between MIN and MAX, return 0 if below MIN
    /// @param amountUSD Borrow amount in USD (18 decimals)
    /// @return Clamped amount
    function _clampBorrowUSD(
        uint256 amountUSD
    ) internal pure returns (uint256) {
        if (amountUSD < MIN_BORROW_USD) return 0;
        return amountUSD > MAX_BORROW_USD ? MAX_BORROW_USD : amountUSD;
    }

    /// @dev Emit callback to execute leverage step on Sepolia
    /// @param borrowAmountUSD Amount to borrow in USD terms (18 decimals)
    /// @param iteration Current iteration number
    /// @param assetDecimals Decimals of the borrow asset (6 for USDC, 18 for DAI)
    function _sendCallback(
        uint256 borrowAmountUSD,
        uint256 iteration,
        uint8 assetDecimals
    ) internal {
        // Convert USD to borrow asset amount dynamically
        // Formula: borrowAssetAmount = borrowAmountUSD / (10 ^ (18 - assetDecimals))
        uint256 borrowAmount;

        if (assetDecimals < 18) {
            // Example: USDC (6 decimals): divide by 10^12
            borrowAmount = borrowAmountUSD / (10 ** (18 - assetDecimals));
        } else {
            // Example: DAI (18 decimals): no conversion needed
            borrowAmount = borrowAmountUSD;
        }

        bytes memory payload = abi.encodeWithSignature(
            "executeLeverageStep(address,address,address,uint256,uint256,uint256)",
            address(0), // Replaced with ReactVM ID by Reactive Network
            borrowAsset,
            weth,
            borrowAmount,
            0, // amountOutMin = 0 (fixes Problem A - calculated on-chain)
            iteration
        );

        emit Callback(
            SEPOLIA_CHAIN_ID,
            leverageAccount,
            CALLBACK_GAS_LIMIT,
            payload
        );
    }

    /// @notice Required by AbstractPausableReactive
    function getPausableSubscriptions()
        internal
        view
        override
        returns (Subscription[] memory)
    {
        Subscription[] memory subs = new Subscription[](2);
        subs[0] = Subscription(
            SEPOLIA_CHAIN_ID,
            leverageAccount,
            TOPIC_DEPOSITED,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        subs[1] = Subscription(
            SEPOLIA_CHAIN_ID,
            leverageAccount,
            TOPIC_LOOP_STEP,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        return subs;
    }

    /// @notice Withdraw native token balance
    function withdrawNative() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "No balance");
        (bool ok, ) = payable(msg.sender).call{value: bal}("");
        require(ok, "Transfer failed");
    }

    /// @notice Emergency update of leverage account
    function updateLeverageAccount(address _newAccount) external onlyOwner {
        require(_newAccount != address(0), "Invalid address");
        leverageAccount = _newAccount;
    }

    /// @notice Update borrow/collateral assets
    function updateAssets(
        address _borrowAsset,
        uint8 _borrowAssetDecimals,
        address _weth
    ) external onlyOwner {
        require(
            _borrowAsset != address(0) && _weth != address(0),
            "Invalid addresses"
        );
        borrowAsset = _borrowAsset;
        borrowAssetDecimals = _borrowAssetDecimals;
        weth = _weth;
    }
}
