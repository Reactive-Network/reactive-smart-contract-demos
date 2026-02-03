// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./MockToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockRouter - DEX + Oracle simulator for testing
contract MockRouter is Ownable {
    // Asset prices in USD (18 decimals). Example: WETH = 3000e18, USDT = 1e18
    mapping(address => uint256) public prices;

    constructor() Ownable(msg.sender) {}

    function setPrice(address token, uint256 price) external onlyOwner {
        prices[token] = price;
    }

    /// @notice Uniswap V2 style swap - burns tokenIn, mints tokenOut
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 /* deadline */
    ) external returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        uint256 priceIn = prices[tokenIn];
        uint256 priceOut = prices[tokenOut];
        require(priceIn > 0 && priceOut > 0, "Price not set");

        uint256 amountOut = (amountIn * priceIn) / priceOut;
        require(amountOut >= amountOutMin, "Slippage error");

        MockToken(tokenIn).burn(msg.sender, amountIn);
        MockToken(tokenOut).mint(to, amountOut);

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }
}
