// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import {RaffluxDao} from "../src/RaffluxDao.sol";

//this a custom nft created on the polygon testnet used to test this
interface myNfts {
    function balanceOf(address) external view returns (uint256);
    function approve(address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract RaffluxTest is Test {
    RaffluxDao rafflux;
    address public address1;
    address public address2;
    using stdStorage for StdStorage;
    address constant myAddress = 0x30bE4D758d86cfb1Ae74Ae698f2CF4BA7dC8d693;
    myNfts punks = myNfts(0x2690080D83460264424BcAB8ceE6afFAbCD6b933);

    
    function setUp() public {
        rafflux = new RaffluxDao();
    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
          .target(token)
          .sig(myNfts(token).balanceOf.selector)
          .with_key(who)
          .checked_write(amt);
    }

    //checks whether it starts a raffle
    function testProposal() public {
      // vm.startPrank(myAddress);
      writeTokenBalance(myAddress, address(punks), 0);
      rafflux.proposeRaffle('testing a raffle', myAddress, block.timestamp, block.timestamp + 2000, 10, 10, address(punks), 4, 0 ether);
      rafflux.buyTicket(0);
      assertEq(rafflux.userTicket(0), 1);
      console.log(msg.sender);
      rafflux.delegateTicket(0, myAddress);
      // assertEq(rafflux.startIndex, 1);
      assertEq(punks.ownerOf(4), myAddress);
      // vm.stopPrank();
    }

    //test the delegateTicket function 
    function testDelegate() public {
      //  vm.expectRevert();
       
    }

    
    function testDeposit() public {
      vm.startPrank(myAddress);
      assertGt(punks.balanceOf(myAddress), 1);
      assertEq(punks.ownerOf(4), myAddress);
      punks.approve(address(rafflux), 4);
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
