// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import './IPayable.sol';
import './ISubscriptionService.sol';

interface ISystemContract is IPayable, ISubscriptionService {
}
