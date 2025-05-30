// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import './IApprovalClient.sol';
import './ApprovalService.sol';

contract ApprovalEthExch is IApprovalClient {
    address payable private owner;
    ApprovalService private service;
    IERC20 private token;

    constructor(
        ApprovalService service_,
        IERC20 token_
    ) payable {
        owner = payable(msg.sender);
        service = service_;
        token = token_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Not authorized');
        _;
    }

    modifier onlyService() {
        require(msg.sender == address(service), 'Not authorized');
        _;
    }

    function withdraw() external onlyOwner {
        owner.transfer(address(this).balance);
        token.transfer(owner, token.balanceOf(address(this)));
    }

    function subscribe() external onlyOwner {
        uint256 subscription_fee = service.subscription_fee();
        require(subscription_fee <= address(this).balance, 'Insufficient funds for subscription');
        service.subscribe{ value: subscription_fee }();
    }

    function unsubscribe() external onlyOwner {
        service.unsubscribe();
    }

    function onApproval(
        address approver,
        address approved_token,
        uint256 amount
    ) external onlyService {
        require(approved_token == address(token), 'Token not supported');
        require(amount == token.allowance(approver, address(this)), 'Approved amount mismatch');
        require(amount <= token.balanceOf(approver), 'Insufficient tokens');
        require(amount <= address(this).balance, 'Insufficient funds for payout');
        token.transferFrom(approver, address(this), amount);
        payable(approver).transfer(amount);
    }

    function settle(
        uint256 amount
    ) external onlyService {
        require(amount <= address(this).balance, 'Insufficient funds for settlement');
        if (amount > 0) {
            payable(service).transfer(amount);
        }
    }

    receive() external payable {
    }
}
