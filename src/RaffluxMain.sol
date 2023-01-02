// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface random {
    function getNumber() external;
}

interface ITest {
    function isERC1155(address nftAddress) external returns (bool);

    function isERC721(address nftAddress) external returns (bool);
}

error reverted();
error transactReverted(string data);
error noTime(bytes32 data);
error pointRevert(string data);

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
contract RaffluxMain is  IERC721Receiver, IERC1155Receiver, Ownable {
    using SafeMath for uint256;
    using ERC165Checker for address;

    /**
     * @dev The contract's constructor initializes the RafluxStorage contract.
     */
    constructor() public payable {
        
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
    event Log_ChangeProposalStatus(uint256 _proposalId, bool _status, address indexed _caller);
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

    // - addPoint: emitted when points are added to an address
    event addPoint(address indexed _user, uint256 _points);
    // - removePoint: emitted when points are removed from an address
    event removePoint(address indexed _user, uint256 _points);

    //State Variable
    bytes4 public constant IID_ITEST = type(ITest).interfaceId;
    bytes4 public constant IID_IERC165 = type(IERC165).interfaceId;
    bytes4 public constant IID_IERC1155 = type(IERC1155).interfaceId;
    bytes4 public constant IID_IERC721 = type(IERC721).interfaceId;
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
    mapping(address => bool) private Validators;

    // Maps the proposal ID to the total amount of Ether collected for the raffle.
    mapping(uint256 => uint256) public totalAmount;

    //maps of proposalId to amount, this mapping is used to track ticket has bought a particular has per proposalId
    mapping(uint256 => mapping(address => uint256)) private totalUserTicket;

    //mapping of proposalId to amount, this mapping is used to track ticket has bought a particular has per proposalId
    mapping(uint256 => mapping(address => uint256)) private maximumUserTicket;

    //mapping of address to address to totalTicket
    mapping(address => uint256) public totalTicket;

    //map of proposalId to buyers
    mapping(uint256 => address[]) private buyers;

    //map of proposalid to buyersTicket
    mapping(uint256 => mapping(address => uint256[])) public ticketId;

    //mapping of addresses to bool, this is used to select a validator
    mapping(address => bool) private valid;

    //map of proposalId to
    mapping(uint256 => bool) private isActive;

    //map of address to bool, to blacklist an address
    mapping(address => bool) private blacklist;

    //map of uint256 to uint256 this is used to check the totalSupply based on each proposalId
    mapping(uint256 => uint256) private totalSupply;

    // A mapping to track the number of points that each address has.
    mapping(uint256 => mapping(address => uint256)) private points;

    // A mapping of conc address to user address to token
    mapping(address => mapping(address => uint256)) private checks;

    //MODIFIERS
    modifier checksTime(uint256 _proposalId) {
        if (timeLeft(_proposalId) == 0) revert noTime("the raffle has closed");

        _;
    }

    modifier onlyValidators() {
        if (valid[msg.sender] != true)
            revert transactReverted("not a validator");

        _;
    }

    //checks if points is zero
    modifier checkZero(uint256 _points) {
        if(_points == 0) revert pointRevert("can't be zero");
        _;
    }

    //FUNCTIONS
        //standard that allows us to recceive erc1155 tokens
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual override returns (bytes4){
      return this.onERC1155Received.selector;
    }

    //standarad that allows us to receive erc1155 in batch
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual override returns (bytes4){
        return this.onERC1155BatchReceived.selector;
    }

    //Standard that allows us to receive erc721 tokens
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == IID_ITEST || interfaceId == IID_IERC165;
    }

    // viewPoints returns the number of points that the given address has.
    function viewPoints(address _user, uint256 _proposalId) public view returns (uint256) {
        return points[_proposalId][_user];
    }

    //update points
    function updatePoints(
        address _user,
        uint256 _points,
        uint256 _proposalId,
        bool _bool
    ) private checkZero(_points)   {
        //if bool is true add to user points else subtract from user points
        if (_bool) {
            points[_proposalId][_user] += _points;
            emit addPoint(_user, _points);
        } else {
            if(viewPoints(_user, _proposalId) < _points) revert pointRevert("not enough available");
            emit removePoint(_user, _points);
            points[_proposalId][_user] -= _points;
        }
    }

    //withdraw nft from user to contract
    function withdrawNft(address _tokenAddress, uint256 _tokenId) private {
        if (isERC721(_tokenAddress)) {
            IERC721 Token = IERC721(_tokenAddress);
            Token.transferFrom(address(this), msg.sender, _tokenId);
        }else if (isERC1155(_tokenAddress)) {
            IERC1155 Tokens = IERC1155(_tokenAddress);
            //   Tokens.transferFrom(address(this), msg.sender, _tokenId, 1, "");
        }
    }
    
    //check if the token is an erc721 token
    function isERC721(address nftAddress) public view returns (bool) {
        return nftAddress.supportsInterface(IID_IERC721);
    }

    //check if the token is erc1155 token
    function isERC1155(address nftAddress) public view returns (bool) {
        return nftAddress.supportsInterface(IID_IERC1155);
    }
    //this allows for the deposit of nft
    function depositNft(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _proposalId
    ) private {
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
        depositNft(_prize, _tokenId, startIndex);
    }

    function getRandomness() public {}

    //this adds or remove status depending  on the value of _status
    function changeValidator(address _user, bool _status) external {
        Validators[_user] = _status;
    }

    //checks whether you are a validtaor or not
    function checkValidator(address _validator) external view returns (bool) {
        return Validators[_validator];
    }

    //
    function buyersOf(uint256 _proposalId, uint256 _index)
        public
        view
        returns (address)
    {
        return buyers[_proposalId][_index];
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
        updatePoints(msg.sender, 10, _proposalId, true);
        ++totalTicket[msg.sender];
        ++maximumUserTicket[_proposalId][msg.sender];
        ++totalUserTicket[_proposalId][msg.sender];
        totalAmount[_proposalId] = totalAmount[_proposalId].add(msg.value);

        buyers[_proposalId].push(msg.sender);
        ticketId[_proposalId][msg.sender].push(
            buyers[_proposalId].length != 1 ? buyers[_proposalId].length - 1 : 0
        );
        isActive[_proposalId] = true;
        
        (bool status, bytes memory data) = address(this).call{
            value: raffles[_proposalId].price
        }("");
        if (status) revert transactReverted(string(data));
        emit Log_BuyTicket(_proposalId, 1, msg.sender);
    }

    function userTicket(uint256 _proposalId) public view returns (uint256) {
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
        // Get the index of the last ticket ID in the ticketId array for the caller
        uint256 lastTicketIdIndex = ticketId[_proposalId][msg.sender].length <=
            1
            ? 0
            : ticketId[_proposalId][msg.sender].length - 1;

        // Get the index of the last buyer in the buyers array
        uint256 lastBuyerIndex = buyers[_proposalId].length <= 1
            ? 0
            : buyers[_proposalId].length - 1;

        //Get the last item in the array for the caller
        uint256 ticketIdIndex = ticketId[_proposalId][msg.sender][
            lastTicketIdIndex
        ];

        // Check if the caller has any available tickets
        if (
            totalUserTicket[_proposalId][msg.sender] == 0 ||
            maximumUserTicket[_proposalId][msg.sender] == 0
        ) revert transactReverted("you have no available ticket");

        // Check if the caller and receiver are the same address
        if (msg.sender == _receiver)
            revert transactReverted("can't delegate to self");

        // Check if the receiver has reached the maximum number of tickets allowed
        if (
            maximumUserTicket[_proposalId][_receiver] >=
            raffles[_proposalId].ticketPerUser
        ) revert transactReverted("maximum ticket reached");

        // Check if the raffle is active
        if (isActive[_proposalId] == false)
            revert transactReverted("raffle is no longer active");

        // Check if the raffle has been stopped
        if (raffles[_proposalId].stop == true)
            revert transactReverted("raffle is no longer active");

        // Update the points for the caller and receiver
        updatePoints(msg.sender, 10, _proposalId, false);
        updatePoints(_receiver, 10, _proposalId, true);

        // If the caller only has one ticket, remove it from the buyers and ticketId arrays and add it to the receiver's ticketId array
        if (
            buyers[_proposalId][
                ticketId[_proposalId][msg.sender][lastBuyerIndex]
            ] == msg.sender
        ) {
            // Remove the ticket from the buyers and ticketId arrays for the caller
            buyers[_proposalId].pop();
            ticketId[_proposalId][msg.sender].pop();
            // Add the ticket to the receivers ticketId array
            buyers[_proposalId].push(_receiver);
            ticketId[_proposalId][_receiver].push(lastTicketIdIndex);
        } else {
            // Add the ticket to the receivers ticketId array
            buyers[_proposalId][ticketIdIndex] = _receiver;
            // Add the ticket to the receivers ticketId array
            ticketId[_proposalId][_receiver].push(ticketIdIndex);
            // Remove the ticket from the caller's ticketId array
            ticketId[_proposalId][msg.sender].pop();
        }
        // Update the ticket ownership for the _receiver
        hasTicket[_proposalId][_receiver] = true;
        // Increment the maximum ticket count for the receiver
        ++maximumUserTicket[_proposalId][_receiver];
        // Increment the total ticket count for the receiver
        ++totalUserTicket[_proposalId][_receiver];
        // Decrement the total ticket count for the caller
        totalUserTicket[_proposalId][msg.sender]--;
        //if this is the last ticket of the user update ownership to false
        if (totalUserTicket[_proposalId][msg.sender] == 0) {
            hasTicket[_proposalId][msg.sender] = false;
        }
        // Emit an event for the ticket delegation
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
        // Get the index of the last ticket ID in the ticketId array for the caller
        uint256 lastTicketIdIndex = ticketId[_proposalId][msg.sender].length <=
            1
            ? 0
            : ticketId[_proposalId][msg.sender].length - 1;

        // Get the index of the last buyer in the buyers array
        uint256 lastBuyerIndex = buyers[_proposalId].length <= 1
            ? 0
            : buyers[_proposalId].length - 1;

        //Get the last item in the array for the caller
        uint256 ticketIdIndex = ticketId[_proposalId][msg.sender][
            lastTicketIdIndex
        ];

        //check if the user has tickets
        if (
            totalUserTicket[_proposalId][msg.sender] == 0 ||
            maximumUserTicket[_proposalId][msg.sender] == 0
        ) revert transactReverted("you have no available ticket");
        //check if proposal is still active
        if (isActive[_proposalId] == false)
            revert transactReverted("raffle is no longer active");
        //decrement  maximumticket for the caller since its a refund
        maximumUserTicket[_proposalId][msg.sender]--;
        //decrement totalticket for the user
        totalUserTicket[_proposalId][msg.sender]--;
        //if this is the last ticket of the user update ownership to false
        if (totalUserTicket[_proposalId][msg.sender] == 0) {
            hasTicket[_proposalId][msg.sender] = false;
        }
        totalAmount[_proposalId] = totalAmount[_proposalId].sub(
            raffles[_proposalId].price
        );
        // Update the points for the caller and receiver
        updatePoints(msg.sender, 10, _proposalId, false);
        
        // If the caller only has one ticket, remove it from the buyers and ticketId arrays
        if (
            buyers[_proposalId][
                ticketId[_proposalId][msg.sender][lastBuyerIndex]
            ] == msg.sender
        ) {
            // Remove the ticket from the buyers and ticketId arrays for the caller
            buyers[_proposalId].pop();
            ticketId[_proposalId][msg.sender].pop();
        } else {
            //last buyers index
            address lastAddress = buyers[_proposalId][lastBuyerIndex];
            //replace the last address with the user address
            buyers[_proposalId][lastBuyerIndex] = buyers[_proposalId][
                ticketIdIndex
            ];
            //replace the userPositionIndex with the last address
            buyers[_proposalId][ticketIdIndex] = lastAddress;
            // Remove the ticket from the caller's ticketId array
            ticketId[_proposalId][msg.sender].pop();
            //remove the last item from the buyers array
            buyers[_proposalId].pop();
        }
        //transfer ticket fee back to user
        (bool status, bytes memory data) = msg.sender.call{
            value: raffles[_proposalId].price
        }("");
        //revert if not succesful
        if (status) revert transactReverted(string(data));
        // Emit an event for the refund ticket
        emit Log_RefundTicket(_proposalId, msg.sender, 1);
    }

    // Function to execute a raffle when the end time is reached or maximum ticket has been sold.
    // Takes the proposal ID as an argument.
    // Reverts if the raffle is not active or has been stopped.
    // Otherwise, selects a random winner from the users who have bought tickets, transfers the prize token to the winner, and resets the contract's internal state for the raffle.
    function executeProposal(uint256 _proposalId) public {
        if (isActive[_proposalId] == false)
            revert transactReverted("proposal no longer active");
        if (raffles[_proposalId].stop == true)
            revert transactReverted("proposal has stopped");
        if (timeLeft(_proposalId) != 0)
            revert transactReverted("proposal time still running");
        isActive[_proposalId] = false;
        //select a winner and add the user
        raffles[_proposalId].winner = buyers[_proposalId][0];
        emit Log_ExecuteProposal(_proposalId, raffles[_proposalId].winner);
        //withdraw token to the winner
        withdrawNft(
            raffles[_proposalId].prize,
            raffles[_proposalId].tokenId
        );
        //transfer ether to owner
        emit Log_ExecuteProposal(_proposalId, raffles[_proposalId].winner);
        (bool status, bytes memory data) = raffles[_proposalId].owner.call{
            value: totalAmount[_proposalId]
        }("");
        if (status) revert transactReverted(string(data));
        // if(Token(raffles[_proposalId].prize).ownerOf(raffles[_proposalId].tokenId) == buyers[_proposalId][0]) revert ("didn't transfer to owner");
    }

    // Function to stop a raffle abruptly or continue the raffle.
    // Takes the proposal ID as an argument.
    function changeProposalStatus(uint256 _proposalId) public onlyValidators {
        emit Log_ChangeProposalStatus(_proposalId, raffles[_proposalId].stop, msg.sender);
        //this continue or stop a proposal
        raffles[_proposalId].stop = !raffles[_proposalId].stop;
        emit Log_ChangeProposalStatus(_proposalId, raffles[_proposalId].stop, msg.sender);
    }

    //this returns the status of the current proposal
    function checkStatus(uint256 _proposalId) public view returns (bool) {
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
