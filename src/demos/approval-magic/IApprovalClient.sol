// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

interface IApprovalClient {
    function onApproval(
        address approver,
        address approved_token,
        uint256 amount
    ) external;

    function settle(
        uint256 amount
    ) external;
}
