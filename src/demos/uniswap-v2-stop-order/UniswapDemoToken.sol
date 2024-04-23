// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';

// Router: 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008
// Factory: 0x7E0987E5b3a30e3f2828572Bb659A548460a3003

contract UniswapDemoToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(tx.origin, 100 ether);
    }
}
