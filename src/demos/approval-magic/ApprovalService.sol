// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';
import './IApprovalClient.sol';

// TODO: A more flexible economic model, keeping track of contracts' debts, and requiring coverage of debt before attempting to resubscribe.
contract ApprovalService is AbstractCallback {
    event Subscribe(
        address indexed subscriber
    );

    event Unsubscribe(
        address indexed subscriber
    );

    address payable private owner;
    uint256 public subscription_fee;
    uint256 private gas_coefficient;
    uint256 private extra_gas;

    mapping(address => bool) private subscribers;

    constructor(
        address callback_sender_addr_,
        uint256 subscription_fee_,
        uint256 gas_coefficient_,
        uint256 extra_gas_
    ) AbstractCallback(callback_sender_addr_) payable {
        owner = payable(msg.sender);
        subscription_fee = subscription_fee_;
        gas_coefficient = gas_coefficient_;
        extra_gas = extra_gas_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Not authorized');
        _;
    }

    function withdraw() external onlyOwner {
        owner.transfer(address(this).balance);
    }

    // TODO: This subscription model does not allow attackers to extract value, but is still vulnerable to attacks where the attackers spends less than the cost to us. Increase the flat fee to avoid this.
    function subscribe() external payable {
        require(msg.value == subscription_fee, 'Incorrect fee');
        require(!subscribers[msg.sender], 'Already subscribed');
        emit Subscribe(msg.sender);
        subscribers[msg.sender] = true;
    }

    function unsubscribe() external {
        require(subscribers[msg.sender], 'Not subscribed');
        emit Unsubscribe(msg.sender);
        subscribers[msg.sender] = false;
    }

    function onApproval(
        address rvm_id,
        IApprovalClient target,
        address approver,
        address approved_token,
        uint256 amount
    ) external authorizedSenderOnly rvmIdOnly(rvm_id) {
        uint256 gas_init = gasleft();
        target.onApproval(approver, approved_token, amount);
        uint256 adjusted_gas_price = tx.gasprice * gas_coefficient * (extra_gas + gas_init - gasleft());
        // TODO: This is just to keep the testing/debugging costs down.
        adjusted_gas_price = adjusted_gas_price > 100 ? 100 : adjusted_gas_price;
        uint256 balance = address(this).balance;
        target.settle(adjusted_gas_price);
        if (address(this).balance - balance != adjusted_gas_price) {
            emit Unsubscribe(address(target));
            subscribers[msg.sender] = false;
        }
    }
}
