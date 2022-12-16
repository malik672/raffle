// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract RafluxDao{

  Token tokens;

  constructor(address _token) public {
     tokens = Token(_token);
  }

   //struct proposal 
   struct Proposal{
     string message;
     uint256 proposalId;
     uint256 votesFor;
     uint256 votesAgainst;
     bool passed;
     uint256 startingTime;
     uint256 endingTime;
     bool locked;
     address sender;
     address _receiver;
     uint256 target;
     bool isActive;
   }

   /*                                     MODIFIERS                               */
   modifier passed(uint256 _id){
     require(proposals[_id].passed == false);
     _;
   }

   //only sender can modify the state variable
   modifier onlySender(uint256 _id){
       require(msg.sender == proposals[_id].sender);
       require(proposals[_id].locked != true);

       _;
   }


   /*                                     MAPPINGS                                */
   // mapping of individual addres to balance
   mapping(address => uint256) balance;

   /*mapping of proposalId to address then boolean
    func: to check if the user has already vote and delegate their vote 
    params: takes in the proposalId, the sender address*/
    mapping(uint256 => mapping(address => bool)) hasVoted;

   //no of users
   uint256 public users;
   uint256 public proposalIds;
   uint256 public deadline = block.timestamp + 30 seconds;
   
    

   Proposal[] public proposals;

 
  /*                                   FUNCTIONS                                    */ 

   //add proposal
   function addProposal
   (string memory _message, address _receiver, uint256 _target)
    public {
     proposalIds++;
     proposals.push(Proposal(_message, proposalIds - 1, 0, 0, false, block.timestamp, block.timestamp + 3 days, false, msg.sender, _receiver, _target,true));
     tokens.registerVoter(proposalIds - 1);
   }

   //vote for the proposal
   function voteFor(uint256 _proposalId) public  passed(_proposalId){
      require(tokens.verifyVoters(msg.sender, _proposalId) == true);
      //to check if proposal has not expired
      require(timeLeft(_proposalId) > 0);
      //to check if sender has not vote
      require(hasVoted[_proposalId][msg.sender] == false, "you have vote");
      //to check whether the sender can vote
      require(tokens.getVotes(msg.sender) > 0, "you can't vote");
      uint256 bal = tokens.getVotes(msg.sender);
      proposals[_proposalId].votesFor += bal;
      //set hasVote to true
      hasVoted[_proposalId][msg.sender] = true;
   }

   //votes against the proposal
   function VoteAgainst(uint256 _proposalId) public  passed(_proposalId){
      require(tokens.verifyVoters(msg.sender, _proposalId) == true);
      //to check if proposal has not expired
      require(timeLeft(_proposalId) > 0);
      //to check if sender has not vote
      require(hasVoted[_proposalId][msg.sender] == false, "you have vote");
      //to check whether the sender can vote
      require(tokens.getVotes(msg.sender) > 0, "you can't vote");
      uint256 bal = tokens.getVotes(msg.sender);
      proposals[_proposalId].votesFor += bal;

      //set hasVote to true
      hasVoted[_proposalId][msg.sender] = true;
   }
 
   //execute the proposal if voting is done and time is up
   function executeProposal(uint256 _proposalId) public passed(_proposalId)  returns(string memory){
      //to check if proposal has expired
     require(timeLeft(_proposalId) == 0);

     require(proposals[_proposalId].sender == msg.sender);
  
     if(proposals[_proposalId].votesFor > proposals[_proposalId].votesAgainst){
       proposals[_proposalId].passed = true;

       (bool success,) = proposals[_proposalId]._receiver.call{value: proposals[_proposalId].target}("");
       require(success, "failed did not send");

       return "success"; 

     }else{
      proposals[_proposalId].isActive = false;
      return "fail";
      
    

     }
   }

   //cancel a proposal
   function cancelProposal(uint256 _proposalId) public passed(_proposalId) onlySender(_proposalId) {
      require(proposals[_proposalId].sender == msg.sender);
      proposals[_proposalId].locked = true;
      proposals[_proposalId].isActive = false;
   }
   

   //time left for a propo
   function timeLeft(uint256 _proposalId) public view returns(uint256){
        if(block.timestamp > proposals[_proposalId].endingTime){
           return 0;
        }else{
          return proposals[_proposalId].endingTime - block.timestamp;
        }
   }
 
}