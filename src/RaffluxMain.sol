// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ITest {
    function isERC1155(address nftAddress) external returns (bool);

    function isERC721(address nftAddress) external returns (bool);
}


/**
 * @title Raffle contract
 * @author Malik_dev
 * @notice This is the main contract for the raffle
 *
 * The RaffluxMain contract allows users to propose a raffle, with details such as the description,
 * owner, start and end time, maximum number of tickets, and prize token. Other users can then buy
 * tickets for the raffle by calling the `buyTicket()` function. When the raffle ends, the winner is
 * chosen and the prize token is transferred to them.
 */

 contract RaffluxMain is  IERC721Receiver, IERC1155Receiver, Ownable {
    using ERC165Checker for address;

    /**
     * @dev The proposedRaffle struct defines the information for a proposed raffle. It includes the
     * owner, description, start and end time, prize token, and other details.
     */
     struct proposedRaffle {
        address owner; //owner of the proposal
        bool stop; //stop, stop sthe proposal abruptly
        uint64 index; //index of the proposal, this increments for every proposal
        uint64 price; //cost of the raffle ticket per user in usd
        address prize; //address of the prize of token
        uint64 maxTicket; //the number of tickets available in total
        uint64 proposedAt; //when the proposal is proposed
        uint64 endTime; //when he proposal should end
        uint64 ticketPerUser; //maximum ticket per user
        uint64 tokenId; //tokenId of the token
        address winner; //winner of the raffle
        string description; //description of raffle
    }

        //Events
        event Log_DelegateTicket(
            uint256 _raffleId,
            address indexed _receiver,
            address indexed _sender
        );
        event Log_BuyTicket(
            uint256 _raffleId,
            uint256 _amount,
            address indexed buyer
        );
        event Log_ChangeRaffleStatus(uint256 _raffleId, bool _status, address indexed _caller);
        event Log_ExecuteRaffle(uint256 _raffleId, address indexed _winner);
        event Log_RefundTicket(
            uint256 _raffleId,
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
        event removePoint(address indexed _user, uint256 _points);
        event addPoint(address indexed _user, uint256 _points);


       /*//////////////////////////////////////////////////////////////
                                 ERRORS
       //////////////////////////////////////////////////////////////*/
       error UnauthorizedCaller(address caller);
       error noTimeRemaining(string data);
       error reverted();
       error transactReverted(string data);

       //MAPPINGS
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
       modifier checksTime(uint256 _raffleId) {
        if (timeLeft(_raffleId) == 0) revert noTime("the raffle has closed");

        _;
       }

       modifier onlyValidators() {
        if (Validators[msg.sender] != true)
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
     function viewPoints(address _user, uint256 _raffleId) public view returns (uint256) {
        return points[_raffleId][_user];        
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
            points[_raffleId][_user] += _points;
            emit addPoint(_user, _points);
        } else {
            if(viewPoints(_user, _raffleId) < _points) revert pointRevert("not enough available");
            //check already prevent for underflow            
            unchecked {
                points[_raffleId][_user] -= _points;
            }
            emit removePoint(_user, _points);
        }
    }

    //withdraw nft from user to contract
    function withdrawNft(address _tokenAddress, uint256 _tokenId) private {
        if (isERC721(_tokenAddress)) {
            IERC721 Token = IERC721(_tokenAddress);
            Token.transferFrom(address(this), msg.sender, _tokenId);
        }else if (isERC1155(_tokenAddress)) {
            IERC1155 Tokens = IERC1155(_tokenAddress);
            Tokens.transferFrom(address(this), msg.sender, _tokenId, 1, 0x0);
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
                false,
                startIndex,
                _price,
                _prize,
                _maxTicket,
                block.timestamp.add(_startTime),
                block.timestamp.add(_endTime),
                _ticketPerUser,
                _tokenId,
                address(0),
                _description
            )
        );
        isActive[startIndex] = true;
        raffles.length == 1 ? startIndex : ++startIndex;
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

    //this adds or remove status depending  on the value of _status
    function changeValidator(address _user, bool _status) external onlyOwner {
        Validators[_user] = _status;
    }

    //this returns buyer of a particular proposal with index specified
    function buyersOf(uint256 _raffleId, uint256 _index)
        public
        view
        returns (address)
    {
        return buyers[_raffleId][_index];
    }

    //checks whether you are a validtaor or not
    function checkValidator(address _validator) external view returns (bool) {
        return Validators[_validator];
    }

       /**
     * @dev Function to buy a ticket for a raffle. Takes the proposal ID and the number of tickets to buy
     * as arguments. Verifies that the raffle is active, the user has not already bought a ticket for the
     * raffle, and the maximum number of tickets has not been reached. If these conditions are met,
     * the user's ticket is added to the raffle and the amount of Ether for the ticket is collected.
     *
     * @param _raffleId The ID of the raffle proposal.
     */
     function buyTicket(uint256 _raffleId)
     public
     payable
     checksTime(_raffleId)
    {
     canVotes[_raffleId] = true;
     if (
         maximumUserTicket[_raffleId][msg.sender] ==
         raffles[_raffleId].ticketPerUser
     ) revert transactReverted("maximum ticket reached");
     if (isActive[_raffleId] != true)
         revert transactReverted("raffle is no longer active");
     if (raffles[_raffleId].stop == true)
         revert transactReverted("raffle has stopped");
     if (raffles[_raffleId].price != msg.value)
         revert transactReverted("Insufficent Funds");
     if(raffles[_raffleId].maxTicket <= totalAmount[_raffleId])
         revert transactReverted("maximum ticket reached");
     hasTicket[_raffleId][msg.sender] = true;
     updatePoints(msg.sender, 10, _raffleId, true);
     ++totalTicket[msg.sender];
     ++maximumUserTicket[_raffleId][msg.sender];
     ++totalUserTicket[_raffleId][msg.sender];
     totalAmount[_raffleId] = totalAmount[_raffleId].add(msg.value);

     buyers[_raffleId].push(msg.sender);
     ticketId[_raffleId][msg.sender].push(
         buyers[_raffleId].length != 1 ? buyers[_raffleId].length - 1 : 0
     );
     isActive[_raffleId] = true;
     
     (bool status, bytes memory data) = address(this).call{
         value: raffles[_raffleId].price
     }("");
     if (status) revert transactReverted(string(data));
     emit Log_BuyTicket(_raffleId, 1, msg.sender);
    }

    //returns the total ticket sold based on raffleId
    function userTicket(uint256 _raffleId) public view returns (uint256) {
        return totalUserTicket[_raffleId][msg.sender];
    }

        /**
     * @dev Function to delegate token ownership to the contract. the
     * token ID, and the address of the token owner as arguments. checks that the user has ticket to delegate.
     * If these conditions are met the function delegates the ticket out.
     * are met, the @param _receiver becomes the owner of the ticket.
     *
     * @param _raffleId The ID.
     * @param _receiver the receiver of the ticket.
     */
    function delegateTicket(uint256 _raffleId, address _receiver) public {
        // Get the index of the last ticket ID in the ticketId array for the caller
        uint256 lastTicketIdIndex = ticketId[_raffleId][msg.sender].length <=
            1
            ? 0
            : ticketId[_raffleId][msg.sender].length - 1;

        // Get the index of the last buyer in the buyers array
        uint256 lastBuyerIndex = buyers[_raffleId].length <= 1
            ? 0
            : buyers[_raffleId].length - 1;

        //Get the last item in the array for the caller
        uint256 ticketIdIndex = ticketId[_raffleId][msg.sender][
            lastTicketIdIndex
        ];

        // Check if the caller has any available tickets
        if (
            totalUserTicket[_raffleId][msg.sender] == 0 ||
            maximumUserTicket[_raffleId][msg.sender] == 0
        ) revert transactReverted("you have no available ticket");

        // Check if the caller and receiver are the same address
        if (msg.sender == _receiver)
            revert transactReverted("can't delegate to self");

        // Check if the receiver has reached the maximum number of tickets allowed
        if (
            maximumUserTicket[_raffleId][_receiver] >=
            raffles[_raffleId].ticketPerUser
        ) revert transactReverted("maximum ticket reached");

        // Check if the raffle is active
        if (isActive[_raffleId] == false)
            revert transactReverted("raffle is no longer active");

        // Check if the raffle has been stopped
        if (raffles[_raffleId].stop == true)
            revert transactReverted("raffle has stopped");

        // Update the points for the caller and receiver
        updatePoints(msg.sender, 10, _raffleId, false);
        updatePoints(_receiver, 10, _raffleId, true);

        // If the caller only has one ticket, remove it from the buyers and ticketId arrays and add it to the receiver's ticketId array
        if (
            buyers[_raffleId][
                ticketId[_raffleId][msg.sender][lastBuyerIndex]
            ] == msg.sender
        ) {
            // Remove the ticket from the buyers and ticketId arrays for the caller
            buyers[_raffleId].pop();
            ticketId[_raffleId][msg.sender].pop();
            // Add the ticket to the receivers ticketId array
            buyers[_raffleId].push(_receiver);
            ticketId[_raffleId][_receiver].push(lastTicketIdIndex);
        } else {
            // Add the ticket to the receivers ticketId array
            buyers[_raffleId][ticketIdIndex] = _receiver;
            // Add the ticket to the receivers ticketId array
            ticketId[_raffleId][_receiver].push(ticketIdIndex);
            // Remove the ticket from the caller's ticketId array
            ticketId[_raffleId][msg.sender].pop();
        }
        // Update the ticket ownership for the _receiver
        hasTicket[_raffleId][_receiver] = true;
        // Increment the maximum ticket count for the receiver
        ++maximumUserTicket[_raffleId][_receiver];
        // Increment the total ticket count for the receiver
        ++totalUserTicket[_raffleId][_receiver];
        // Decrement the total ticket count for the caller
        totalUserTicket[_raffleId][msg.sender]--;
        //if this is the last ticket of the user update ownership to false
        if (totalUserTicket[_raffleId][msg.sender] == 0) {
            hasTicket[_raffleId][msg.sender] = false;
        }
        // Emit an event for the ticket delegation
        emit Log_DelegateTicket(_raffleId, _receiver, msg.sender);
    }

    //this function checks if a user can vote on a raffleId;
    function canVote(uint256 _raffleId) external {
        canVotes[_raffleId] = true;
    }

    // Function to execute a raffle when the end time is reached or maximum ticket has been sold.
    // Takes the raffle ID as an argument.
    // Reverts if the raffle is not active or has been stopped.
    // Otherwise, selects a random winner from the users who have bought tickets, transfers the prize token to the winner, and resets the contract's internal state for the raffle.
    function executeRaffle(uint256 _raffleId) public {
        if (isActive[_raffleId] == false)
            revert transactReverted("proposal no longer active");
        if (raffles[_raffleId].stop == true)
            revert transactReverted("proposal has stopped");
        if (timeLeft(_raffleId) != 0)
            revert transactReverted("proposal time still running");
        isActive[_raffleId] = false;
        //select a winner and add the user
        raffles[_raffleId].winner = buyers[_raffleId][0];
        emit Log_ExecuteRaffle(_raffleId, raffles[_raffleId].winner);
        //withdraw token to the winner
        withdrawNft(
            raffles[_raffleId].prize,
            raffles[_raffleId].tokenId
        );
        //transfer ether to owner
        emit Log_ExecuteRaffle(_raffleId, raffles[_raffleId].winner);
        (bool status, bytes memory data) = raffles[_raffleId].owner.call{
            value: totalAmount[_raffleId]
        }("");
        if (status) revert transactReverted(string(data));
    }

    // Function to stop a raffle abruptly or continue the raffle.
    function changeRaffleStatus(uint256 _raffleId) public onlyValidators  {
        //this continue or stop a proposal
        raffles[_raffleId].stop = !raffles[_raffleId].stop;
        emit Log_ChangeRaffleStatus(_raffleId, raffles[_raffleId].stop, msg.sender);
    }

    //this returns the status of the current raffle
    function checkStatus(uint256 _raffleId) public view returns (bool) {
        return raffles[_raffleId].stop;
    }

    /**
     * @dev Function to get the remaining time until a raffle ends.
     * @param _raffleId The ID of the proposal for which to get the remaining time.
     * @return The number of seconds until the raffle ends.
     */
     function timeLeft(uint256 _rafffleId) public view returns (uint256) {
        if (block.timestamp < raffles[_raffleId].endTime) {
            return raffles[_raffleId].endTime.sub(block.timestamp);
        } else {
            return 0;
        }
     }
 }