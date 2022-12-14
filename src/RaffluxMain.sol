pragma solidity ^0.8.4;

import "./RafluxStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

error reverted();
error transactReverted(bytes32 data);

//this the main contract in the raffle
contract RaffluxMain is RafluxStorage {
    RafluxStorage Storage;
    using SafeMath for uint256;

    constructor() payable{
      Storage = new RafluxStorage();
    }

    //STRUCT
    //struct of proposal
    struct proposedRaffle {
        address owner; //owner of the proposal
        string description; //description of raffle
        uint256 index; //index of the proposal, this increments for every proposal
        uint256 price; //cost of the raffle ticket per user
        address prize; //address of the prize of token
        bool isActive; //this as to be set to true for raffle to take place, by default all raffle is active
        uint256 maxTicket; //the number of tickets available in total
        uint256 proposedAt; //when the proposal is proposed
        uint256 endTime; //when he proposal should end
        uint256 ticketPerUser; //maximum ticket per user
        uint256 _tokenId;//tokenId of the token
        bool stop; //stop, stop sthe proposal abruptly
    }

    //State Variable
    bytes32 public constant type721 = keccak256("ERC721");
    bytes32 public constant type1155 = keccak256("ERC1155");
    uint256 startIndex = 0;
    //proposed raffles
    proposedRaffle[] public raffles;
    uint256 public current;

    //Mapping of proposal id to it timeLeft
    mapping(uint256 => uint256) public timeLefts;

    //Mapping of proposalId to user, this is to track user that have paid for a particular raffle
    mapping(uint256 => mapping(address => bool)) public hasTicket;

    //mapping of proposalId to total amount it has ammased
    mapping(uint256 => uint256) public totalAmount;

    //mapping of proposalId to amount, this mapping is used to track ticket has bought a particular has per proposalId
    mapping(uint256 => mapping(address => uint256)) private totalUserTicket;

    //mapping of proposalId to amount, this mapping is used to track ticket has bought a particular has per proposalId
    mapping(uint256 => mapping(address => uint256)) private maximumUserTicket;

    //mapping of address to address to totalTicket
    mapping(address => uint256) public totalTicket;

    //FUNCTIONS
    //this function propose raffle 
    function proposeRaffle(
        string memory _description,
        address _owner,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTicket,
        uint256 _ticketPerUser,
        address _prize,
        uint256 _tokenId,
        uint256 _price
    ) public {
        raffles.push(
            proposedRaffle(
                _owner,
                _description,
                startIndex,
                _price,
                _prize,
                true,
                _maxTicket,
                block.timestamp.add(_startTime),
                block.timestamp.add(_endTime),
                _ticketPerUser,
                _tokenId,
                false
            )
        );
        startIndex++;
        Storage.depositNft(_prize, _tokenId);
    }

    // this function allows user to buy ticket based on proposal Ticket
    function buyTicket(uint256 _proposalId) public {
      if(totalUserTicket[_proposalId][msg.sender] <= raffles[_proposalId].ticketPerUser) revert transactReverted(keccak256("maximum ticket reached"));
      hasTicket[_proposalId][msg.sender] = true;
      totalTicket[msg.sender] += 1;
      totalUserTicket[_proposalId][msg.sender]++;
      (bool status, bytes memory data) = address(this).call{value: raffles[_proposalId].price}("");
      if(status) revert transactReverted(bytes32(data));
    }

    //this function allows you to delegate ticket to another user
    function delegateTicket(uint256 _proposalId, address _receiver) public { 
        if(totalUserTicket[_proposalId][_receiver] <= raffles[_proposalId].ticketPerUser) revert transactReverted(keccak256("maximum ticket reached"));
        hasTicket[_proposalId][msg.sender] = true;
        totalUserTicket[_proposalId][msg.sender]--;
    }
    
    //this calls for the execution of a proposal, takes in the proposalId and executes the function
    function executeProposal(uint _proposalId) public {
       if(raffles[_proposalId].isActive == true) revert reverted();
       raffles[_proposalId].isActive = false;
    }

    //this function stop the proposal and all ticket fee collected are returned to the user

    //  //list the nft
    //  function list(address _tokenAddress, uint _tokenId, uint _time){
    //     //list the nft
    //     RaffluxStorage.depositNft(_tokenAddress, _tokenId);
    //  }

    //timeleft
    function timeLeft(uint256 _proposalId) public view returns (uint256) {
        return raffles[_proposalId].endTime.sub(raffles[_proposalId].proposedAt);
    }
}
