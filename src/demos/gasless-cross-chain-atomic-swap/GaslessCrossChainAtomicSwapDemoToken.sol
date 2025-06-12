// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';

contract GaslessCrossChainAtomicSwapDemoToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(tx.origin, 100 ether);
    }
}
