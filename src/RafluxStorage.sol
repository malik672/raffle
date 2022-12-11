pragma solidity ^0.8;


import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract RafluxStorage {
  //State Variables
  address public caller;

  //mappings
  mapping(address => uint256) points;


  constructor(address _caller) payable {
    caller = _caller;
  }

  //functions
  function transfer() public {

  } 
}