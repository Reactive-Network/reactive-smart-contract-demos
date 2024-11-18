// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
pragma abicoder v2;

import "../../../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "../../../../AbstractCallback.sol";

/**
 * Please read the README.md file in regards to using the Permit.  Basically,
 * not all ERC-20's implement the IERC20Permit interface.
 *
 * This implementation is an example of how to use the Permit process to initialize
 * the swap transaction in one step.  Refer to the other implementation outside of
 * this Permit folder for the one-step swap without the IERC20Permit interface.
 */
interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract PermitContract is AbstractCallback {


    address constant SWAP_ROUTER = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;


    address private callback_sender;

    event SwapApproved(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint24 fee
    );

    event CallbackReceived(
        address indexed topic_1,
        address indexed topic_2,
        address indexed topic_3,
        uint256 amountIn,
        uint256 amountOutMin,
        uint24 fee
    );

    event UniSwapV3Swap(
        address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    

    constructor(address _callback_sender) AbstractCallback(_callback_sender) payable  {
    }
    receive() external payable { }

  

    function approveSwapWithPermit(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint24 fee,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Use Permit to approve tokens
        IERC20Permit(tokenIn).permit(msg.sender, address(this), amountIn, deadline, v, r, s);

        // Transfer tokens from user's EOA to this contract
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer Failed");

        // Approve router to spend tokens from this contract
        require(IERC20(tokenIn).approve(SWAP_ROUTER, amountIn), "Approval Failed");

        // Emit event for RSC to pick up
        emit SwapApproved(msg.sender, tokenIn, tokenOut, amountIn, amountOutMin, fee);
    }

    function callback(
        address, /* sender */
        address topic_1,
        address topic_2,
        address topic_3,
        uint256 amountIn,
        uint256 amountOutMin,
        uint24 fee
    ) external {
        emit CallbackReceived(topic_1, topic_2, topic_3, amountIn, amountOutMin, fee);
        _uniSwapV3Swap(topic_1, topic_2, topic_3, amountIn, amountOutMin, fee);
    }

    function withdraw(address token) external {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        IERC20(token).transfer(msg.sender, balance);
    }


    function _uniSwapV3Swap(
        address user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint24 fee
    ) private {
        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: user,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin, // naively set to zero for demo purposes
            sqrtPriceLimitX96: 0 // naively set to zero for demo purposes
        });

        uint256 amountOut = ISwapRouter02(SWAP_ROUTER).exactInputSingle(params);

        emit UniSwapV3Swap(user, tokenIn, tokenOut, amountIn, amountOut);
    }
}
