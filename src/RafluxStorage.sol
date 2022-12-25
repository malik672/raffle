// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error pointRevert(string data);

interface ITest {
    function isERC1155(address nftAddress) external returns (bool);

    function isERC721(address nftAddress) external returns (bool);
}

// RafluxStorage is a contract that can store ERC-1155 and ERC-721 tokens,
// and track the number of points that each address has.
contract RafluxStorage is IERC721Receiver,IERC1155Receiver,Ownable {
    using ERC165Checker for address;

    //State Variables
    // - caller: the address of the caller of the contract
    // - IID_ITEST: the interface ID of the ITest interface
    // - IID_IERC165: the interface ID of the IERC165 interface
    // - IID_IERC1155: the interface ID of the IERC1155 interface
    // - IID_IERC721: the interface ID of the IERC721 interface
    address public caller;
    bytes4 public constant IID_ITEST = type(ITest).interfaceId;
    bytes4 public constant IID_IERC165 = type(IERC165).interfaceId;
    bytes4 public constant IID_IERC1155 = type(IERC1155).interfaceId;
    bytes4 public constant IID_IERC721 = type(IERC721).interfaceId;

    // A mapping to track the number of points that each address has.
    mapping(uint256 => mapping(address => uint256)) points;
    // A mapping of conc address to user address to token
    mapping(address => mapping(address => uint256)) checks;

    //constructor
    constructor() payable {}

    //EVENTS
    // - addPoint: emitted when points are added to an address
    // - removePoint: emitted when points are removed from an address
    event addPoint(address indexed _user, uint256 _points);
    event removePoint(address indexed _user, uint256 _points);

    //MODIFIER
    //checks if points is zero
    modifier checkZero(uint256 _points) {
        if(_points == 0) revert pointRevert("can't be zero");
        _;
    }

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

    //FUNCTIONS
    //check if the token is an erc721 token
    function isERC721(address nftAddress) public view returns (bool) {
        return nftAddress.supportsInterface(IID_IERC721);
    }

    //check if the token is erc1155 token
    function isERC1155(address nftAddress) public view returns (bool) {
        return nftAddress.supportsInterface(IID_IERC1155);
    }

    //transfer nft from user to contract
    function depositNft(address _tokenAddress, uint256 _tokenId, uint256 _proposalId) public virtual onlyOwner {
        updatePoints(msg.sender, 10, _proposalId, true);
        if (isERC721(_tokenAddress)) {
            IERC721 Token = IERC721(_tokenAddress);
            Token.safeTransferFrom(msg.sender, address(this), _tokenId);
        } else if (isERC1155(_tokenAddress)) {
            IERC1155 Tokens = IERC1155(_tokenAddress);
            Tokens.safeTransferFrom(msg.sender, address(this), _tokenId, 1, "");
        }
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

    
    function updatePoints(
        address _user,
        uint256 _points,
        uint256 _proposalId,
        bool _bool
    ) public checkZero(_points)  onlyOwner {
        //if bool is true add to user points else subtract from user points
        if (_bool) {
            points[_proposalId][_user] += _points;
            emit addPoint(_user, _points);
        } else {
            emit removePoint(_user, _points);
            points[_proposalId][_user] -= _points;
        }
    }

    //withdraw nft from user to contract
    function withdrawNft(address _tokenAddress, uint256 _tokenId) public onlyOwner {
        if (isERC721(_tokenAddress)) {
            IERC721 Token = IERC721(_tokenAddress);
            Token.safeTransferFrom(address(this), msg.sender, _tokenId);
        }else if (isERC1155(_tokenAddress)) {
            IERC1155 Tokens = IERC1155(_tokenAddress);
              Tokens.safeTransferFrom(address(this), msg.sender, _tokenId, 1, "");
        }
    }
}
