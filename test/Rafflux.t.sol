// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {RafluxStorage} from "../src/RafluxStorage.sol";

//this a custom nft created on the polygon testnet used to test this
interface myNfts {
    function balanceOf(address) external view returns (uint256);
    function approve(address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract RaffluxTest is Test {
    RafluxStorage Storage;
    address public address1;
    address public address2;
    using stdStorage for StdStorage;
    address constant myAddress = 0x30bE4D758d86cfb1Ae74Ae698f2CF4BA7dC8d693;
    myNfts punks = myNfts(0x2690080D83460264424BcAB8ceE6afFAbCD6b933);

    // RafluxStorage Rafflux = RafluxStorage();
    function setUp() public {
        Storage = new RafluxStorage();
    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
          .target(token)
          .sig(myNfts(token).balanceOf.selector)
          .with_key(who)
          .checked_write(amt);
    }

    //checks whether it mints
    function testRed() public {
      vm.prank(myAddress);
      writeTokenBalance(myAddress, address(punks), 0);
      // emit log_named_uint("Current ether balance of myAddress", myAddress.balance);
      // emit log_named_uint("Dai balance of myAddress before", punks.balanceOf(myAddress));
      // emit log_named_uint("Dai balance of myAddress before", punks.balanceOf(myAddress));
      vm.stopPrank();
    }

    
    function testDeposit() public {
      vm.stopPrank();
      vm.startPrank();
      vm.prank(0x30bE4D758d86cfb1Ae74Ae698f2CF4BA7dC8d693);
      assertGt(punks.balanceOf(myAddress), 1);
      assertEq(punks.ownerOf(4), myAddress);
      // assertNotEq(address(Storage), address(0));
      emit log_named_address("Current address of sender", msg.sender);
      punks.approve(address(Storage), 4);
      // Storage.depositNft(address(punks), 4, 0);
      vm.stopPrank();
    }

    // //test points 
    // function testUpdatePointExpectedRevert() public {
    //   // vm.expectRevert("can't be zero");
    //   vm.prank(Storage.owner());
    //   /*since the update functions and other mutable functions cann only be called by the owner, we will have to transfer ownership  */
    //   Storage.updatePoints(myAddress, 10, 0,  true);
    //   //check it add points
    //   assertEq(Storage.viewPoints(myAddress, 0), 10);
    //   //check it removes points
    //   //the two(2) here is useless since the remove points remove all points a user has and equate it to zero
    //   Storage.updatePoints(myAddress, 10,0, false);
    //   // //check if point equal to zero after removal
    //   assertEq(Storage.viewPoints(myAddress,0), 0);      
    // }

    // function testDeposit() public {};
}
