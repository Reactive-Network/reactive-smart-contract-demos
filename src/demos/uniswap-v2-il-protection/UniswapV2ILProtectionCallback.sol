// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../../../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../../../lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./RescuableBase.sol";

/**
 * @title UniswapV2ILProtectionCallback
 * @notice Personal IL protection system for Uniswap V2 LP positions
 * @dev Each user deploys their own instance. Monitors reserve ratio divergence
 *      from entry snapshot and auto-exits the LP position when IL threshold is breached.
 */
contract UniswapV2ILProtectionCallback is AbstractCallback, RescuableBase {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event PositionRegistered(
        address indexed pair,
        uint256 indexed positionId,
        address token0,
        address token1,
        uint256 lpAmount,
        uint256 entryReserve0,
        uint256 entryReserve1,
        uint256 divergenceThresholdBps
    );

    event PositionExited(
        address indexed pair,
        uint256 indexed positionId,
        uint256 lpAmountBurned,
        uint256 amount0Received,
        uint256 amount1Received
    );

    event PositionCancelled(uint256 indexed positionId);
    event PositionPaused(uint256 indexed positionId);
    event PositionResumed(uint256 indexed positionId);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error PositionNotActive(uint256 positionId);
    error DivergenceNotBreached(uint256 positionId);
    error InsufficientLPBalance(uint256 positionId);
    error InsufficientLPAllowance(uint256 positionId);

    // -------------------------------------------------------------------------
    // Types
    // -------------------------------------------------------------------------

    enum PositionStatus {
        Active,
        Paused,
        Cancelled,
        Exited
    }

    /**
     * @notice Represents an LP position registered for IL protection
     * @param id                    Unique position ID
     * @param pair                  Uniswap V2 pair address
     * @param token0                token0 of the pair
     * @param token1                token1 of the pair
     * @param lpAmount              LP tokens to protect (pulled from owner on exit)
     * @param entryReserve0         reserve0 at position registration time
     * @param entryReserve1         reserve1 at position registration time
     * @param divergenceThresholdBps  max allowed divergence in basis points (e.g. 2000 = 20%)
     * @param status                current lifecycle status
     * @param createdAt             block timestamp at registration
     * @param exitedAt              block timestamp at exit (0 if not exited)
     */
    struct LPPosition {
        uint256 id;
        address pair;
        address token0;
        address token1;
        uint256 lpAmount;
        uint256 entryReserve0;
        uint256 entryReserve1;
        uint256 divergenceThresholdBps;
        PositionStatus status;
        uint256 createdAt;
        uint256 exitedAt;
    }

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    address public immutable owner;
    IUniswapV2Router02 public immutable router;

    LPPosition[] public positions;
    uint256 public nextPositionId;

    uint256 private constant DEADLINE_OFFSET = 300; // 5 min swap deadline
    uint256 private constant BPS_DENOMINATOR = 10000; // basis points denominator
    uint256 private constant MIN_LP_AMOUNT = 1000; // dust guard

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier validPosition(uint256 positionId) {
        require(positionId < positions.length, "Position does not exist");
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _owner, address _callbackSender, address _router) payable AbstractCallback(_callbackSender) {
        owner = _owner;
        router = IUniswapV2Router02(_router);
    }

    // -------------------------------------------------------------------------
    // Owner-facing: register / manage positions
    // -------------------------------------------------------------------------

    /**
     * @notice Register an LP position for IL protection
     * @param pair                    Uniswap V2 pair address
     * @param lpAmount                Amount of LP tokens to protect
     * @param divergenceThresholdBps  Divergence threshold in basis points (e.g. 2000 = 20%)
     * @return positionId             ID of the newly created position
     *
     * @dev Entry reserve snapshot is taken at registration time.
     *      The owner must hold at least `lpAmount` LP tokens and have approved
     *      this contract to spend them before calling executeExit.
     */
    function registerPosition(address pair, uint256 lpAmount, uint256 divergenceThresholdBps)
        external
        onlyOwner
        returns (uint256 positionId)
    {
        require(pair != address(0), "Invalid pair");
        require(lpAmount >= MIN_LP_AMOUNT, "LP amount too small");
        require(divergenceThresholdBps > 0 && divergenceThresholdBps < BPS_DENOMINATOR, "Invalid threshold");

        // Snapshot current reserves as entry point
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "Pair has no liquidity");

        // Verify owner actually holds the LP tokens
        require(IERC20(pair).balanceOf(owner) >= lpAmount, "Insufficient LP balance");

        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        positionId = nextPositionId;
        positions.push(
            LPPosition({
                id: positionId,
                pair: pair,
                token0: token0,
                token1: token1,
                lpAmount: lpAmount,
                entryReserve0: uint256(reserve0),
                entryReserve1: uint256(reserve1),
                divergenceThresholdBps: divergenceThresholdBps,
                status: PositionStatus.Active,
                createdAt: block.timestamp,
                exitedAt: 0
            })
        );

        nextPositionId++;

        emit PositionRegistered(
            pair, positionId, token0, token1, lpAmount, uint256(reserve0), uint256(reserve1), divergenceThresholdBps
        );
    }

    /**
     * @notice Cancel a position (no exit, just stop monitoring)
     */
    function cancelPosition(uint256 positionId) external onlyOwner validPosition(positionId) {
        LPPosition storage pos = positions[positionId];
        require(pos.status == PositionStatus.Active || pos.status == PositionStatus.Paused, "Cannot cancel");
        pos.status = PositionStatus.Cancelled;
        emit PositionCancelled(positionId);
    }

    /**
     * @notice Pause monitoring for a position
     */
    function pausePosition(uint256 positionId) external onlyOwner validPosition(positionId) {
        LPPosition storage pos = positions[positionId];
        require(pos.status == PositionStatus.Active, "Not active");
        pos.status = PositionStatus.Paused;
        emit PositionPaused(positionId);
    }

    /**
     * @notice Resume a paused position
     */
    function resumePosition(uint256 positionId) external onlyOwner validPosition(positionId) {
        LPPosition storage pos = positions[positionId];
        require(pos.status == PositionStatus.Paused, "Not paused");
        pos.status = PositionStatus.Active;
        emit PositionResumed(positionId);
    }

    // -------------------------------------------------------------------------
    // RSC-facing: execute exit
    // -------------------------------------------------------------------------

    /**
     * @notice Execute IL-protection exit for a position (called by RSC via Reactive Network)
     * @dev Performs a final on-chain divergence check before executing.
     *      Pulls LP tokens from owner, removes liquidity via router, returns
     *      token0 + token1 directly to owner.
     * @param positionId  ID of the position to exit
     */
    function executeExit(
        address, /* sender — unused, authorizedSenderOnly handles auth */
        uint256 positionId
    )
        external
        authorizedSenderOnly
        validPosition(positionId)
    {
        LPPosition storage pos = positions[positionId];

        // Status check
        if (pos.status != PositionStatus.Active) {
            revert PositionNotActive(positionId);
        }

        // Final on-chain divergence check
        (uint112 reserve0Now, uint112 reserve1Now,) = IUniswapV2Pair(pos.pair).getReserves();
        if (!_isDivergenceBreached(pos, reserve0Now, reserve1Now)) {
            revert DivergenceNotBreached(positionId);
        }

        // Verify owner still holds enough LP tokens
        uint256 ownerLPBalance = IERC20(pos.pair).balanceOf(owner);
        if (ownerLPBalance < pos.lpAmount) {
            revert InsufficientLPBalance(positionId);
        }

        // Verify owner has approved this contract to spend LP tokens
        uint256 ownerLPAllowance = IERC20(pos.pair).allowance(owner, address(this));
        if (ownerLPAllowance < pos.lpAmount) {
            revert InsufficientLPAllowance(positionId);
        }

        // Mark exited before external calls (CEI pattern)
        pos.status = PositionStatus.Exited;
        pos.exitedAt = block.timestamp;

        // Pull LP tokens from owner
        IERC20(pos.pair).safeTransferFrom(owner, address(this), pos.lpAmount);

        // Approve router to spend LP tokens
        IERC20(pos.pair).forceApprove(address(router), pos.lpAmount);

        // Remove liquidity — tokens land in this contract first, then forwarded to owner
        (uint256 amount0, uint256 amount1) = router.removeLiquidity(
            pos.token0,
            pos.token1,
            pos.lpAmount,
            0, // amountAMin — no slippage protection for simplicity; can be added
            0, // amountBMin
            owner,
            block.timestamp + DEADLINE_OFFSET
        );

        emit PositionExited(pos.pair, positionId, pos.lpAmount, amount0, amount1);
    }

    // -------------------------------------------------------------------------
    // View helpers
    // -------------------------------------------------------------------------

    /**
     * @notice Returns all position IDs
     */
    function getAllPositions() external view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](positions.length);
        for (uint256 i = 0; i < positions.length; i++) {
            ids[i] = i;
        }
        return ids;
    }

    /**
     * @notice Returns only active position IDs
     */
    function getActivePositions() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].status == PositionStatus.Active) count++;
        }
        uint256[] memory active = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].status == PositionStatus.Active) {
                active[idx++] = i;
            }
        }
        return active;
    }

    /**
     * @notice Returns current divergence in basis points for a position
     * @dev Useful for off-chain monitoring dashboards
     */
    function getCurrentDivergenceBps(uint256 positionId)
        external
        view
        validPosition(positionId)
        returns (uint256 divergenceBps)
    {
        LPPosition storage pos = positions[positionId];
        (uint112 reserve0Now, uint112 reserve1Now,) = IUniswapV2Pair(pos.pair).getReserves();
        divergenceBps = _computeDivergenceBps(pos, reserve0Now, reserve1Now);
    }

    // -------------------------------------------------------------------------
    // Internal: divergence logic
    // -------------------------------------------------------------------------

    /**
     * @notice Compute reserve-ratio divergence in basis points relative to entry snapshot
     *
     * Entry ratio:   R_entry   = entryReserve0 / entryReserve1
     * Current ratio: R_current = reserve0Now   / reserve1Now
     *
     * To stay in integer arithmetic:
     *   divergenceBps = |R_current - R_entry| / R_entry * BPS_DENOMINATOR
     *                 = |reserve0Now * entryReserve1 - entryReserve0 * reserve1Now|
     *                   / (entryReserve0 * reserve1Now) * BPS_DENOMINATOR
     *
     * We use Math.mulDiv for overflow-safe 256-bit arithmetic.
     */
    function _computeDivergenceBps(LPPosition storage pos, uint112 reserve0Now, uint112 reserve1Now)
        internal
        view
        returns (uint256)
    {
        // Cross-multiply to compare ratios without division
        // currentCross  = reserve0Now   * entryReserve1
        // entryCross    = entryReserve0 * reserve1Now
        uint256 currentCross = Math.mulDiv(uint256(reserve0Now), pos.entryReserve1, 1);
        uint256 entryCross = Math.mulDiv(pos.entryReserve0, uint256(reserve1Now), 1);

        uint256 delta = currentCross > entryCross ? currentCross - entryCross : entryCross - currentCross;

        // divergenceBps = delta / entryCross * BPS_DENOMINATOR
        return Math.mulDiv(delta, BPS_DENOMINATOR, entryCross);
    }

    /**
     * @notice Returns true if current reserves have diverged beyond the position's threshold
     */
    function _isDivergenceBreached(LPPosition storage pos, uint112 reserve0Now, uint112 reserve1Now)
        internal
        view
        returns (bool)
    {
        uint256 divergenceBps = _computeDivergenceBps(pos, reserve0Now, reserve1Now);
        return divergenceBps >= pos.divergenceThresholdBps;
    }

    // -------------------------------------------------------------------------
    // Rescue
    // -------------------------------------------------------------------------

    function _rescueRecipient() internal view override returns (address) {
        return owner;
    }

    function rescueETH(uint256 amount) external override onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        _rescueETH(amount);
    }

    function rescueAllETH() external override onlyOwner {
        _rescueETH(0);
    }

    function rescueERC20(address token, uint256 amount) external override onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        _rescueERC20(token, amount);
    }

    function rescueAllERC20(address token) external override onlyOwner {
        _rescueERC20(token, 0);
    }
}
