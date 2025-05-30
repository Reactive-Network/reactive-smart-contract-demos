// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import '../../../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import './IApprovalClient.sol';
import './ApprovalService.sol';

contract ApprovalMagicSwap is IApprovalClient {
    address private constant ROUTER_ADDR = 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008;
    uint private constant DEADLINE = 2707391655;

    address payable private owner;
    ApprovalService private service;
    IERC20 private token0;
    IERC20 private token1;
    IUniswapV2Router02 private router;

    constructor(
        ApprovalService service_,
        IERC20 token0_,
        IERC20 token1_
    ) payable {
        owner = payable(msg.sender);
        service = service_;
        token0 = token0_;
        token1 = token1_;
        router = IUniswapV2Router02(ROUTER_ADDR);
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
        require(approved_token == address(token0) || approved_token == address(token1), 'Token not supported');
        require(amount == IERC20(approved_token).allowance(approver, address(this)), 'Approved amount mismatch');
        require(amount <= IERC20(approved_token).balanceOf(approver), 'Insufficient tokens');
        assert(IERC20(approved_token).transferFrom(approver, address(this), amount));
        assert(IERC20(approved_token).approve(address(router), amount));
        address[] memory path = new address[](2);
        path[0] = approved_token;
        path[1] = approved_token == address(token0) ? address(token1) : address(token0);
        uint256[] memory tokens = router.swapExactTokensForTokens(amount, 0, path, address(this), DEADLINE);
        assert(IERC20(path[1]).transfer(approver, tokens[1]));
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
