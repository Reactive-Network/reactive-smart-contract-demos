// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title RescuableBase
 * @notice Abstract contract providing rescue functionality for ETH and ERC20 tokens
 */
abstract contract RescuableBase {
    using SafeERC20 for IERC20;

    event ETHRescued(address indexed to, uint256 amount);
    event ERC20Rescued(address indexed token, address indexed to, uint256 amount);

    /**
     * @notice Returns the address that can rescue funds
     */
    function _rescueRecipient() internal view virtual returns (address);

    /**
     * @notice Internal function to rescue ETH
     * @param amount Amount to rescue (0 for full balance)
     */
    function _rescueETH(uint256 amount) internal {
        uint256 balance = address(this).balance;
        uint256 rescueAmount = amount == 0 ? balance : amount;
        require(rescueAmount <= balance, "Insufficient ETH balance");
        require(rescueAmount > 0, "No ETH to rescue");

        address recipient = _rescueRecipient();
        (bool success,) = payable(recipient).call{value: rescueAmount}("");
        require(success, "ETH transfer failed");

        emit ETHRescued(recipient, rescueAmount);
    }

    /**
     * @notice Internal function to rescue ERC20 tokens
     * @param token Token address to rescue
     * @param amount Amount to rescue (0 for full balance)
     */
    function _rescueERC20(address token, uint256 amount) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 rescueAmount = amount == 0 ? balance : amount;
        require(rescueAmount <= balance, "Insufficient token balance");
        require(rescueAmount > 0, "No tokens to rescue");

        address recipient = _rescueRecipient();
        IERC20(token).safeTransfer(recipient, rescueAmount);

        emit ERC20Rescued(token, recipient, rescueAmount);
    }

    /**
     * @notice Rescue specific amount of ETH
     * @param amount Amount to rescue
     */
    function rescueETH(uint256 amount) external virtual {
        require(amount > 0, "Amount must be greater than 0");
        _rescueETH(amount);
    }

    /**
     * @notice Rescue all ETH balance
     */
    function rescueAllETH() external virtual {
        _rescueETH(0);
    }

    /**
     * @notice Rescue specific amount of ERC20 tokens
     * @param token Token address to rescue
     * @param amount Amount to rescue
     */
    function rescueERC20(address token, uint256 amount) external virtual {
        require(amount > 0, "Amount must be greater than 0");
        _rescueERC20(token, amount);
    }

    /**
     * @notice Rescue all balance of ERC20 token
     * @param token Token address to rescue
     */
    function rescueAllERC20(address token) external virtual {
        _rescueERC20(token, 0);
    }
}
