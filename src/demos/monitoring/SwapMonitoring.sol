// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import './Monitoring.sol';

contract SwapMonitoring is Monitoring {
    uint256 private constant SWAP_TOPIC_0 = 0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822;
    uint256 private constant THR = 1 ether;

    constructor() Monitoring(0, address(0), SWAP_TOPIC_0) payable {}

    function shouldCallback(
        uint256 /* evtChainId */,
        address /* evtContract */,
        uint256 /* evtTopic0 */,
        uint256 /* evtTopic1 */,
        uint256 /* evtTopic2 */,
        uint256 /* evtTopic3 */,
        bytes calldata data
    ) override internal pure returns (bool) {
        (uint256 a0, uint256 a1, uint256 a2, uint256 a3) = abi.decode(data, ( uint256, uint256, uint256, uint256 ));
        return a0 >= THR || a1 >= THR || a2 >= THR || a3 >= THR;
    }
}
