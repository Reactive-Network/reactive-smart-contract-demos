// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../AbstractCallback.sol";

contract Governance is Ownable, AbstractCallback {
    uint256 public proposalCount;
    uint256 public voteThreshold = 100;

    // Custom Errors
    error CannotVoteOnOwnProposal();
    error VotingPeriodEnded();
    error AlreadyVoted();
    error VotingPeriodNotEnded();
    error ProposalAlreadyExecuted();
    error OnlyProposerCanDelete();

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        uint256 deadline;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public votes;
    mapping(uint256 => uint256) public proposalDeadlines;

    event ProposalCreated(uint256 id, address proposer, string description);
    event Voted(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 id);
    event ProposalRejected(uint256 id);
    event ProposalDeadlineReached(uint256 indexed id, uint256 deadline);
    event ProposalForThresholdReached(uint256 indexed id);
    event ProposalAgainstThresholdReached(uint256 indexed id);

    constructor(address _callback_sender) AbstractCallback(_callback_sender) payable Ownable(msg.sender) {
    }
    receive() external payable {}

    function createProposal(string memory description) external {
        proposalCount++;
        uint256 deadline = block.timestamp + 24 hours;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            executed: false,
            deadline: deadline
        });

        proposalDeadlines[proposalCount] = deadline;

        emit ProposalCreated(proposalCount, msg.sender, description);
        checkProposalDeadlines();
    }

    function vote(uint256 proposalId, bool support) external {
        address voter = msg.sender;
        Proposal storage proposal = proposals[proposalId];
        checkProposalDeadlines();

        if (voter == proposal.proposer) {
            revert CannotVoteOnOwnProposal();
        }

        if (block.timestamp >= proposal.deadline) {
            revert VotingPeriodEnded();
        }

        if (votes[proposalId][voter]) {
            revert AlreadyVoted();
        }

        if (proposals[proposalId].votesFor >= voteThreshold) {
            emit ProposalForThresholdReached(proposalId);
        }
        else if (proposals[proposalId].votesAgainst >= voteThreshold) {
            emit ProposalAgainstThresholdReached(proposalId);
        }
        else if (support) {
            proposal.votesFor++;
            votes[proposalId][voter] = true;
            emit Voted(proposalId, voter, support);
        } else {
            votes[proposalId][voter] = true;
            emit Voted(proposalId, voter, support);
            proposal.votesAgainst++;
        }
    }

    function executeProposal(address /*sender*/, uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        checkProposalDeadlines();


        if (proposal.executed) {
            revert ProposalAlreadyExecuted();
        }

        if (proposal.votesFor > proposal.votesAgainst) {
            proposal.executed = true;
            emit ProposalExecuted(proposalId);
        } else {
            emit ProposalRejected(proposalId);
        }
    }

    function DeleteProposal(address /*sender*/, uint256 proposalId) public {
        delete proposals[proposalId];
        delete proposalDeadlines[proposalId];
    }

    function checkProposalDeadlines() public {
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (block.timestamp > proposalDeadlines[i] && proposalDeadlines[i] != 0) {
                emit ProposalDeadlineReached(i, proposalDeadlines[i]);
                proposalDeadlines[i] = 0; // Set to 0 to avoid emitting the event multiple times
            }
        }
    }
}
