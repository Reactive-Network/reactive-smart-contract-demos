// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title MockToken - ERC20 with Permit for testing (WETH, USDT)
contract MockToken is ERC20, ERC20Permit {
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) ERC20Permit(name) {}

    // public mint for test
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // public burn for test
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
