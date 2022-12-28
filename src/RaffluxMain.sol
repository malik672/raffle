// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./RafluxStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface random {
    function getNumber() external;
}

error reverted();
error transactReverted(string data);
error noTime(bytes32 data);

/**
 * @title RaffluxMain
 * @author Rafflux team
 * @notice This is the main contract for the raffle
 *
 * The RaffluxMain contract allows users to propose a raffle, with details such as the description,
 * owner, start and end time, maximum number of tickets, and prize token. Other users can then buy
 * tickets for the raffle by calling the `buyTicket()` function. When the raffle ends, the winner is
 * chosen and the prize token is transferred to them.
 */
contract RaffluxMain is RafluxStorage {
    RafluxStorage Storage;
    using SafeMath for uint256;

    /**
     * @dev The contract's constructor initializes the RafluxStorage contract.
     */
    constructor() public payable {
        Storage = new RafluxStorage();
    }

    /**
     * @dev The proposedRaffle struct defines the information for a proposed raffle. It includes the
     * owner, description, start and end time, prize token, and other details.
     */
    struct proposedRaffle {
        address owner; //owner of the proposal
        string description; //description of raffle
        uint256 index; //index of the proposal, this increments for every proposal
        uint256 price; //cost of the raffle ticket per user
        address prize; //address of the prize of token
        uint256 maxTicket; //the number of tickets available in total
        uint256 proposedAt; //when the proposal is proposed
        uint256 endTime; //when he proposal should end
        uint256 ticketPerUser; //maximum ticket per user
        uint256 tokenId; //tokenId of the token
        bool stop; //stop, stop sthe proposal abruptly
        address winner; //winner of the raffle
    }

    //Events
    event Log_DelegateTicket(
        uint256 _proposalId,
        address indexed _receiver,
        address indexed _sender
    );
    event Log_BuyTicket(
        uint256 _proposalId,
        uint256 _amount,
        address indexed buyer
    );
    event Log_ChangeProposalStatus(uint256 _proposalId, bool _status);
    event Log_ExecuteProposal(uint256 _proposalId, address indexed _winner);
    event Log_RefundTicket(
        uint256 _proposalId,
        address _receiver,
        uint256 _amount
    );
    event Log_ProposeRaffle(
        string _description,
        address indexed _owner,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTicket,
        uint256 _ticketPerUser,
        address indexed _prize,
        uint256 _tokenId,
        uint256 _price
    );

    //State Variable
    bytes32 public constant type721 = keccak256("ERC721"); // The bytes32 representation of the string "ERC721".
    bytes32 public constant type1155 = keccak256("ERC1155"); // The bytes32 representation of the string "ERC1155".
    uint256 public startIndex = 0; // The starting index for new proposals.
    //proposed raffles
    proposedRaffle[] public raffles;
    uint256 public currentValidators;

    // Mappings to track the status of each raffle.
    // Maps the proposal ID to the remaining time until the raffle ends.
    mapping(uint256 => uint256) public timeLefts;

    //Maps the raffleId to a bool, this checks if the user can vote
    mapping(uint256 => bool) canVotes; 

    // Maps the proposal ID and user address to whether the user has bought a ticket for the raffle.
    mapping(uint256 => mapping(address => bool)) public hasTicket;

    //map of address to bool used to set a validator
    mapping(address => bool) public Validators;

    // Maps the proposal ID to the total amount of Ether collected for the raffle.
    mapping(uint256 => uint256) public totalAmount;

    //maps of proposalId to amount, this mapping is used to track ticket has bought a particular has per proposalId
    mapping(uint256 => mapping(address => uint256)) private totalUserTicket;

    //mapping of proposalId to amount, this mapping is used to track ticket has bought a particular has per proposalId
    mapping(uint256 => mapping(address => uint256)) private maximumUserTicket;

    //mapping of address to address to totalTicket
    mapping(address => uint256) public totalTicket;

    //map of proposalId to buyers
    mapping(uint256 => address[]) public buyers;

    //map of proposalid to buyersTicket
    mapping(uint256 => mapping(address => uint256[])) public ticketId;

    //mapping of addresses to bool, this is used to select a validator
    mapping(address => bool) valid;

    //map of proposalId to
    mapping(uint256 => bool) isActive;

    //map of address to bool, to blacklist an address
    mapping(address => bool) blacklist;


    //MODIFIERS
    modifier checksTime(uint256 _proposalId) {
        if (timeLeft(_proposalId) == 0) revert noTime("the raffle has closed");

        _;
    }

    modifier onlyValidators() {
        if(valid[msg.sender] != true) revert transactReverted("not a validator");

        _;
    }


    //FUNCTIONS

    //this allos for the deposit of nft
    function depositNft( address _tokenAddress, uint256 _tokenId, uint256 _proposalId) override public {
             updatePoints(msg.sender, 10, _proposalId, true);
        if (isERC721(_tokenAddress)) {
            IERC721 Token = IERC721(_tokenAddress);
            Token.safeTransferFrom(msg.sender, address(this), _tokenId);
        } else if (isERC1155(_tokenAddress)) {
            IERC1155 Tokens = IERC1155(_tokenAddress);
            Tokens.safeTransferFrom(msg.sender, address(this), _tokenId, 1, "");
        }
    }

    /**
     * @dev Function to propose a raffle. Takes the description, owner, start and end time, maximum
     * number of tickets, ticket per user, prize token, token ID, and price per ticket as arguments.
     * Adds a new proposedRaffle to the raffles array with the specified information. Deposits the
     * prize token into the RafluxStorage contract.
     *
     * @param _description The description of the raffle.
     * @param _owner The address of the owner of the raffle proposal.
     * @param _startTime The start time for the raffle.
     * @param _endTime The end time for the raffle.
     * @param _maxTicket The maximum number of tickets for the raffle.
     * @param _ticketPerUser The maximum number of tickets per user.
     * @param _prize The address of the prize token for the raffle.
     * @param _tokenId The ID of the prize token.
     * @param _price The price per ticket for the raffle.
     */

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
                _maxTicket,
                block.timestamp.add(_startTime),
                block.timestamp.add(_endTime),
                _ticketPerUser,
                _tokenId,
                false,
                address(0)
            )
        );
        isActive[startIndex] = true;
        raffles.length == 1 ? startIndex : startIndex++;
        emit Log_ProposeRaffle(
            _description,
            _owner,
            _startTime,
            _endTime,
            _maxTicket,
            _ticketPerUser,
            _prize,
            _tokenId,
            _price
        );
        (bool success, bytes memory data) = address(Storage).delegatecall(
            abi.encodeWithSignature(
                "depositNft(address, uint256)",
                _prize,
                _tokenId
            )
        );
        if (success) revert transactReverted(string(data));
        // depositNft(_prize, _tokenId, startIndex);
    }

    function getRandomness() public {}

    //this adds or remove status depending  on the value of _status
    function changeValidator(address _user, bool _status) external {
       Validators[_user] = _status;
    }

    //checks whether you are a validtaor or not
    function checkValidator(address _validator) view external returns(bool){
      return Validators[_validator];
    }

    /**
     * @dev Function to buy a ticket for a raffle. Takes the proposal ID and the number of tickets to buy
     * as arguments. Verifies that the raffle is active, the user has not already bought a ticket for the
     * raffle, and the maximum number of tickets has not been reached. If these conditions are met,
     * the user's ticket is added to the raffle and the amount of Ether for the ticket is collected.
     *
     * @param _proposalId The ID of the raffle proposal.
     */
    function buyTicket(uint256 _proposalId)
        public
        payable
        checksTime(_proposalId)
    {
        canVotes[_proposalId] = true;
        if (
            maximumUserTicket[_proposalId][msg.sender] ==
            raffles[_proposalId].ticketPerUser
        ) revert transactReverted("maximum ticket reached");
        if (isActive[_proposalId] != true)
            revert transactReverted("raffle is no longer active");
        if (raffles[_proposalId].stop == true)
            revert transactReverted("raffle is no longer active");
        if (raffles[_proposalId].price != msg.value)
            revert transactReverted("Insufficent Funds");
        hasTicket[_proposalId][msg.sender] = true;
        updatePoints(msg.sender,10, _proposalId, true);
        ++totalTicket[msg.sender];
        ++maximumUserTicket[_proposalId][msg.sender];
        ++totalUserTicket[_proposalId][msg.sender];
        totalAmount[_proposalId] = totalAmount[_proposalId].add(msg.value);
        buyers[_proposalId].push(msg.sender);
        ticketId[_proposalId][msg.sender].push(buyers[_proposalId].length != 1 ? buyers[_proposalId].length - 1 : 0);
        emit Log_BuyTicket(_proposalId, 1, msg.sender);
        (bool status, bytes memory data) = address(this).call{
            value: raffles[_proposalId].price
        }("");
        if (status) revert transactReverted(string(data));
    }

    function userTicket(uint256 _proposalId) public view returns(uint256){
     return totalUserTicket[_proposalId][msg.sender];
    }

    /**
     * @dev Function to delegate token ownership to the contract. the
     * token ID, and the address of the token owner as arguments. checks that the user has ticket to delegate.
     * If these conditions are met the function delegates the ticket out.
     * are met, the @param _receiver becomes the owner of the ticket.
     *
     * @param _proposalId The ID.
     * @param _receiver the receiver of the ticket.
     */
    function delegateTicket(uint256 _proposalId, address _receiver) public {
        if (
            totalUserTicket[_proposalId][msg.sender] == 0 ||
            maximumUserTicket[_proposalId][msg.sender] == 0
        ) revert transactReverted("you have no available ticket");
        if (
            msg.sender == _receiver
        ) revert transactReverted("can't delegate to self");
        if (
            maximumUserTicket[_proposalId][_receiver] >=
            raffles[_proposalId].ticketPerUser
        ) revert transactReverted("maximum ticket reached");
        if (isActive[_proposalId] == false)
            revert transactReverted("raffle is no longer active");
        if (raffles[_proposalId].stop == true)
            revert transactReverted("raffle is no longer active");
        updatePoints(msg.sender,10, _proposalId, false);
        updatePoints(_receiver,10, _proposalId, true);
        hasTicket[_proposalId][msg.sender] = true;
        ++maximumUserTicket[_proposalId][_receiver];
        ++totalUserTicket[_proposalId][_receiver];
        totalUserTicket[_proposalId][msg.sender]--;
        emit Log_DelegateTicket(_proposalId, _receiver, msg.sender);
    }
 
    //this function checks if a user can vote on a raffleId;
    function canVote(uint256 _raffleId) external {
       canVotes[_raffleId] = true;
    }

    // Function to refund a ticket if the raffle is stopped before it ends.
    // Takes the proposal ID as an argument.
    // Reverts if the raffle is not stopped or the user has not bought a ticket.
    // Otherwise, updates the contract's internal state and sends the refund to the user.
    function refundTicket(uint256 _proposalId) public checksTime(_proposalId) {
        if (
            totalUserTicket[_proposalId][msg.sender] == 0 ||
            maximumUserTicket[_proposalId][msg.sender] == 0
        ) revert transactReverted("you have no available ticket");
        if (isActive[_proposalId] == true)
            revert transactReverted("raffle is no longer active");
        maximumUserTicket[_proposalId][msg.sender] -= 1;
        totalUserTicket[_proposalId][msg.sender] -= 1;
        if (totalUserTicket[_proposalId][msg.sender] == 0) {
            hasTicket[_proposalId][msg.sender] = false;
        }
        totalAmount[_proposalId] = totalAmount[_proposalId].sub(
            raffles[_proposalId].price
        );
        updatePoints(msg.sender, 10, _proposalId, false);
        emit Log_RefundTicket(_proposalId, msg.sender, 1);
        (bool status, bytes memory data) = msg.sender.call{
            value: raffles[_proposalId].price
        }("");
        if (status) revert transactReverted(string(data)); 
    }

    // Function to execute a raffle when the end time is reached or maximum ticket has been sold.
    // Takes the proposal ID as an argument.
    // Reverts if the raffle is not active or has been stopped.
    // Otherwise, selects a random winner from the users who have bought tickets, transfers the prize token to the winner, and resets the contract's internal state for the raffle.
    function executeProposal(uint256 _proposalId) public {
        if (isActive[_proposalId] == false) revert transactReverted("proposal no longer active");
        if (raffles[_proposalId].stop == true) revert transactReverted("proposal has stopped");
        if (timeLeft(_proposalId) != 0) revert transactReverted("proposal time still running");
        isActive[_proposalId] = false;
        //select a winner and add the user
        raffles[_proposalId].winner = buyers[_proposalId][0];
        //withdraw token to the winner
        Storage.withdrawNft(
            raffles[_proposalId].prize,
            raffles[_proposalId].tokenId
        );
        //transfer ether to owner
        emit Log_ExecuteProposal(_proposalId, raffles[_proposalId].winner);
        (bool status, bytes memory data) = raffles[_proposalId].owner.call{
            value: totalAmount[_proposalId]
        }("");
        if (status) revert transactReverted(string(data));
    }

    // Function to stop a raffle abruptly or continue the raffle.
    // Takes the proposal ID as an argument.
    function changeProposalStatus(uint256 _proposalId) public onlyValidators(){
        //this continue or stop a proposal
        raffles[_proposalId].stop = !raffles[_proposalId].stop;
        emit Log_ChangeProposalStatus(_proposalId, raffles[_proposalId].stop);
    }

    //this returns the status of the current proposal
    function checkStatus(uint256 _proposalId) public view  returns(bool){
        return raffles[_proposalId].stop;
    }


    /**
     * @dev Function to get the remaining time until a raffle ends.
     * @param _proposalId The ID of the proposal for which to get the remaining time.
     * @return The number of seconds until the raffle ends.
     */
    function timeLeft(uint256 _proposalId) public view returns (uint256) {
        if (block.timestamp < raffles[_proposalId].endTime) {
            return raffles[_proposalId].endTime.sub(block.timestamp);
        } else {
            return 0;
        }
    }
}
