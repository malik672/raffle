// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./RaffluxValidator.sol";
contract RaffluxDao is RaffluxValidator{
    RaffluxValidator Validator;

    constructor() {
        Validator = new RaffluxValidator();
    }

    //Mapping of proposald to boolean
    mapping(uint256 => bool) public isValid;

    //Events
    event Log_Proposal(
        string _description,
        address indexed _proposer,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _raffleId,
        uint256 _functionId
    );

    event Log_Vote(
      address indexed _user,
      uint256 _voteFor,
      uint256 _voteAgainst,
      uint256 _proposalId
    );

    event Log_ExecuteProposalDao(
      uint256 _proposalId, 
      uint256 _voteFor, 
      uint256 _voteAgainst
    );

    // The contract's struct for storing proposal information.
    struct Proposal {
     address proposer; // The address of the proposer.
     string description; // The description of the proposal.
     uint startTime; // The deadline for voting on the proposal.
     uint endTime; // The deadline for executing the proposal.
     uint256 voteAgainst;
     uint256 voteFor;
     uint256 raffleId;
     uint256 functionId;
     bool isExecuted; // Whether the proposal has been executed.
    }

    //State Variable
    Proposal[] public proposals;
    uint256 treshold;
    uint256 public currentProposalId;

    //this is to start a proposal
    function startProposal(
        string memory _description,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _raffleId,
        uint256 _functionId
    ) public {
        proposals.push(
                Proposal(
                msg.sender,
                _description,
                block.timestamp + _startTime,
                block.timestamp + _endTime,
                0,
                0,
                _raffleId,
                _functionId,
                true
            )
        );
        isValid[proposals.length - 1] = true;
        emit Log_Proposal(_description, msg.sender, _startTime, _endTime, _raffleId, _functionId);
    }

    //function to vote for or against a proposal
    function Vote(uint256 _proposalId, bool _status) public {
      if(Validator.viewPoints(msg.sender, proposals[_proposalId].raffleId) < 10)
         revert transactReverted("you don't have enough points to vote");
      if(isValid[_proposalId] != true)
        revert transactReverted("proposalId not valid");
      if(block.timestamp < proposals[_proposalId].endTime)
        revert transactReverted("proposal still active");
      if(proposals[_proposalId].voteAgainst >= proposals[_proposalId].voteFor)
        revert transactReverted("proposal did not pass");
      if(_status == true){
       proposals[_proposalId].voteFor++;
       emit Log_Vote(msg.sender, proposals[_proposalId].voteFor, proposals[_proposalId].voteAgainst, _proposalId);
      }else{
       proposals[_proposalId].voteAgainst++;
       emit Log_Vote(msg.sender, proposals[_proposalId].voteFor, proposals[_proposalId].voteAgainst, _proposalId);
      }
    }

    //this to end a proposal
    //SWITCH THIS TO IF/ELSE
    function executeProposals(uint256 _proposalId) public {
      if(isValid[_proposalId] != true) 
        revert transactReverted("proposalId not valid");
      if(block.timestamp < proposals[_proposalId].endTime) 
        revert transactReverted("proposal still active");
      if(proposals[_proposalId].voteAgainst >= proposals[_proposalId].voteFor) 
        revert transactReverted("proposal did not pass");
      isValid[_proposalId] = false;
      if (proposals[_proposalId].functionId == 0) {
        // This block of code will be executed if x is 0.
        //  Validator.changeProposalStatus(proposals[_proposalId].raffleId);
      }
      if(proposals[_proposalId].functionId == 1){
        // This block of code will be executed if x is 1.
        // Validator.executeProposal(proposals[_proposalId].raffleId);
      }
      if(proposals[_proposalId].functionId == 2){
        // This block of code will be executed if x is 2.
        // Validator.executeProposal(proposals[_proposalId].raffleId);
      }
      emit Log_ExecuteProposalDao(_proposalId, proposals[_proposalId].voteFor, proposals[_proposalId].voteAgainst);
    }
}