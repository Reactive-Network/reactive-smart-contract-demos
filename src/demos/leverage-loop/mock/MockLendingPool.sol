// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./MockRouter.sol";
import "./MockToken.sol";

/// @title MockLendingPool - Aave-style lending simulator for testing
contract MockLendingPool {
    MockRouter public router;

    mapping(address => mapping(address => uint256)) public supplies;
    mapping(address => mapping(address => uint256)) public borrowings;

    address[] public assets;
    mapping(address => bool) public isAsset;

    constructor(address _router) {
        router = MockRouter(_router);
    }

    function addAsset(address token) external {
        if (!isAsset[token]) {
            assets.push(token);
            isAsset[token] = true;
        }
    }

    function supply(address asset, uint256 amount) external {
        MockToken(asset).transferFrom(msg.sender, address(this), amount);
        supplies[msg.sender][asset] += amount;
    }

    function borrow(address asset, uint256 amount) external {
        borrowings[msg.sender][asset] += amount;

        (, , uint256 ltv) = getUserAccountData(msg.sender);
        require(ltv <= 8000, "LTV limit exceeded"); // Max 80%

        MockToken(asset).mint(msg.sender, amount);
    }

    function repay(address asset, uint256 amount) external {
        require(borrowings[msg.sender][asset] >= amount, "Repay exceeds debt");
        MockToken(asset).transferFrom(msg.sender, address(this), amount);
        borrowings[msg.sender][asset] -= amount;
    }

    function withdraw(address asset, uint256 amount) external {
        require(
            supplies[msg.sender][asset] >= amount,
            "Insufficient collateral"
        );
        supplies[msg.sender][asset] -= amount;

        (, , uint256 ltv) = getUserAccountData(msg.sender);
        if (borrowings[msg.sender][asset] > 0) {
            require(ltv <= 8000, "Withdrawal exceeds LTV limit");
        }

        MockToken(asset).transfer(msg.sender, amount);
    }

    /// @notice Returns user position in USD terms
    /// @return totalCollateralUSD Total collateral value
    /// @return totalDebtUSD Total debt value
    /// @return ltv Loan-to-value ratio (basis points, 7500 = 75%)
    function getUserAccountData(
        address user
    )
        public
        view
        returns (uint256 totalCollateralUSD, uint256 totalDebtUSD, uint256 ltv)
    {
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            uint256 price = router.prices(asset);

            if (supplies[user][asset] > 0) {
                totalCollateralUSD += (supplies[user][asset] * price) / 1e18;
            }
            if (borrowings[user][asset] > 0) {
                totalDebtUSD += (borrowings[user][asset] * price) / 1e18;
            }
        }

        if (totalCollateralUSD == 0) {
            return (0, totalDebtUSD, 0);
        }

        ltv = (totalDebtUSD * 10000) / totalCollateralUSD;
    }
}
