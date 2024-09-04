// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';

contract ApprovalDemoToken is ERC20 {
    mapping(address => bool) private recipients;

    constructor(
        string memory name,
        string memory symbol
    ) ERC20(
    name,
    symbol
    ) {
        _mint(tx.origin, 100 ether);
    }

    function request() external {
        require(!recipients[msg.sender], 'Already received yours');
        recipients[msg.sender] = true;
        _mint(msg.sender, 1 ether);
    }
}
