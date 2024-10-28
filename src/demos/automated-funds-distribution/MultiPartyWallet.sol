// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../AbstractCallback.sol";

contract MultiPartyWallet is AbstractCallback {
    uint256 public creationTime;
    uint256 public totalContributions;
    bool public walletClosed;
    uint256 public minimumContribution;
    uint256 public closureTime;
    uint256 public additionalFunds;

    struct Shareholder {
        uint256 contribution;
        uint256 share;
    }

    mapping(address => Shareholder) public shareholders;
    address[] public shareholderAddresses;
    mapping(address => uint256) private shareholderIndex;
    bool[] public shareholderActive;

    IERC20 public memeCoin;
    uint256 public memeCoinsPerEth;

    event MemeCoinsDistributed(address indexed shareholder, uint256 amount);
    event ContributionReceived(address indexed contributor, uint256 amount);
    event WalletClosed();
    event FundsDistributed(uint256 amount);
    event ShareCalculated(address indexed shareholder, uint256 share);
    event MinimumContributionUpdated(uint256 newMinimum);
    event SharesUpdated();
    event FallbackCalled(address sender, uint256 amount);
    event ClosureTimeUpdated(uint256 newClosureTime);
    event FundsReceived(address sender, uint256 amount);
    event FundsDistributedDirectly(uint256 amount);
    event ShareholderLeft(address indexed shareholder, uint256 amountWithdrawn, uint256 feesPaid);

    // Custom errors
    error WalletClosedError();
    error ContributionTooLowError();
    error NotClosedError();
    error MinimumContributionZeroError();
    error ClosureTimeInPastError();
    error WalletNotReadyForClosureError();
    error RewardTransferFailedError();
    error NoFundsToDistributeError();
    error TransferFailedError();
    error MemeCoinTransferFailedError();
    error NotShareholderError();
    error ShareholderAlreadyLeftError();
    error InvalidMinimumContributionError();

    modifier onlyOpen() {
        if (walletClosed) revert WalletClosedError();
        _;
    }

    modifier onlyClosed() {
        if (!walletClosed) revert NotClosedError();
        _;
    }

    constructor(address _callback_sender) AbstractCallback(_callback_sender) payable {
    }

    function initialize(uint256 _minimumContribution, uint256 _closureTime, address _memeCoinAddress, uint256 _memeCoinsPerEth) public {
        creationTime = block.timestamp;
        walletClosed = false;
        minimumContribution = _minimumContribution;
        closureTime = _closureTime;
        memeCoin = IERC20(_memeCoinAddress);
        memeCoinsPerEth = _memeCoinsPerEth;
        shareholderActive = new bool[](0);
    }

    function setMemeCoin(address _memeCoinAddress, uint256 _memeCoinsPerEth) external {
        memeCoin = IERC20(_memeCoinAddress);
        memeCoinsPerEth = _memeCoinsPerEth;
    }

    fallback() external payable {
        emit FallbackCalled(msg.sender, msg.value);
        if (walletClosed) {
            additionalFunds += msg.value;
            emit FundsReceived(msg.sender, msg.value);
        } else {
            contribute();
        }
    }

    function setMinimumContribution(uint256 _newMinimum) external onlyOpen {
        if (_newMinimum == 0) revert MinimumContributionZeroError();
        minimumContribution = _newMinimum;
        emit MinimumContributionUpdated(_newMinimum);
    }

    function setClosureTime(uint256 _newClosureTime) external onlyOpen {
        if (_newClosureTime <= block.timestamp) revert ClosureTimeInPastError();
        closureTime = _newClosureTime;
        emit ClosureTimeUpdated(_newClosureTime);
    }

    function contribute() public payable onlyOpen {
        if (msg.value < minimumContribution) revert ContributionTooLowError();

        if (shareholders[msg.sender].contribution == 0) {
            shareholderIndex[msg.sender] = shareholderAddresses.length;
            shareholderAddresses.push(msg.sender);
            shareholderActive.push(true);
        }

        shareholders[msg.sender].contribution += msg.value;
        totalContributions += msg.value;

        emit ContributionReceived(msg.sender, msg.value);
    }

    function closeWallet() external onlyOpen {
        if (block.timestamp < closureTime) revert WalletNotReadyForClosureError();
        walletClosed = true;

        // Distribute 1000 meme coins as a reward to the caller
        uint256 rewardAmount = 1000 * 10**18; // Assuming 18 decimals for the meme coin
        if (!memeCoin.transfer(msg.sender, rewardAmount)) revert RewardTransferFailedError();

        emit WalletClosed();
        emit MemeCoinsDistributed(msg.sender, rewardAmount);
    }

    function updateShares(address /*sender*/) external onlyClosed {
        for (uint256 i = 0; i < shareholderAddresses.length; i++) {
            if (shareholderActive[i]) {
                address shareholderAddress = shareholderAddresses[i];
                shareholders[shareholderAddress].share = (shareholders[shareholderAddress].contribution * 1e18) / totalContributions;
                emit ShareCalculated(shareholderAddress, shareholders[shareholderAddress].share);
            }
        }
        emit SharesUpdated();
    }

    function distributeAllFunds(address /*sender*/) external onlyClosed {
        uint256 fundsToDistribute = additionalFunds;
        if (fundsToDistribute == 0) revert NoFundsToDistributeError();

        for (uint256 i = 0; i < shareholderAddresses.length; i++) {
            if (shareholderActive[i]) {
                address shareholderAddress = shareholderAddresses[i];
                uint256 shareAmount = (fundsToDistribute * shareholders[shareholderAddress].share) / 1e18;

                if (shareAmount > 0) {
                    (bool success, ) = payable(shareholderAddress).call{value: shareAmount}("");
                    if (!success) revert TransferFailedError();

                    if (address(memeCoin) != address(0) && memeCoinsPerEth > 0) {
                        uint256 memeCoinsAmount = (shareAmount * memeCoinsPerEth) / 1e18;
                        if (!memeCoin.transfer(shareholderAddress, memeCoinsAmount)) revert MemeCoinTransferFailedError();
                        emit MemeCoinsDistributed(shareholderAddress, memeCoinsAmount);
                    }
                }
            }
        }

        additionalFunds = 0;
        emit FundsDistributedDirectly(fundsToDistribute);
    }

    function leaveShareholding() external onlyClosed {
        Shareholder storage shareholder = shareholders[msg.sender];
        if (shareholder.contribution == 0) revert NotShareholderError();
        if (!shareholderActive[shareholderIndex[msg.sender]]) revert ShareholderAlreadyLeftError();

        uint256 shareAmount = shareholder.contribution;
        uint256 feeAmount = (shareAmount * 5) / 100; // 5% fee
        uint256 withdrawAmount = shareAmount - feeAmount;

        // Mark shareholder as inactive
        shareholderActive[shareholderIndex[msg.sender]] = false;

        // Update total contributions
        totalContributions -= shareholder.contribution;

        // Reset shareholder's data
        shareholder.contribution = 0;
        shareholder.share = 0;

        // Transfer funds
        (bool success, ) = payable(msg.sender).call{value: withdrawAmount}("");
        if (!success) revert TransferFailedError();

        emit ShareholderLeft(msg.sender, withdrawAmount, feeAmount);
    }

    receive() external payable onlyClosed {
        additionalFunds += msg.value;
        emit FundsReceived(msg.sender, msg.value);
    }
}