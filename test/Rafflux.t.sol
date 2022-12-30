// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import {RaffluxDao} from "../src/RaffluxDao.sol";
import {RaffluxMain} from "../src/RaffluxMain.sol";
import {RafluxStorage} from "../src/RafluxStorage.sol";

//this a custom nft created on the polygon testnet used to test this
interface myNfts {
    function balanceOf(address) external view returns (uint256);
    function approve(address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract RaffluxTest is Test {
    RaffluxDao rafflux;
    RaffluxMain main;
    address public address1;
    address public address2;
    using stdStorage for StdStorage;
    address constant myAddress = 0x30bE4D758d86cfb1Ae74Ae698f2CF4BA7dC8d693;
    myNfts punks = myNfts(0x2690080D83460264424BcAB8ceE6afFAbCD6b933);

    
    function setUp() public {
        // rStorage = new RafluxStorage();
        rafflux = new RaffluxDao();
        main = new RaffluxMain();
    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
          .target(token)
          .sig(myNfts(token).balanceOf.selector)
          .with_key(who)
          .checked_write(amt);
    }

    function writeProposal(uint256 _proposalId) internal {
     address[] memory buy;

      stdstore
        .target(address(main))
        .sig(main.buyersOf.selector)
        .with_key(_proposalId)
        .checked_write(address(0));
    }

    // //checks whether it starts a raffle
    // function testRaffleProposal() public {
    //   vm.startPrank(myAddress);
    //   writeTokenBalance(myAddress, address(punks), 0);
    //   main.proposeRaffle('testing a raffle', myAddress, block.timestamp, block.timestamp + 1000, 10, 10, address(punks), 4, 0 ether);
    //   main.buyTicket(0);
    //   assertEq(main.userTicket(0), 1);
    //   main.delegateTicket(0, address(punks));
    //   // assertEq(rafflux.startIndex, 1);
    //   assertEq(punks.ownerOf(4), myAddress);
    //   vm.stopPrank();
    // }

    //checks whether the proposal is valid for execution
    function testExecuteProposal() public {
      testDeposit();
      vm.startPrank(myAddress);
      console.log(main.thisStorage(), main.thisMain());
      
      // punks.approve(address(main), 3);
      // punks.approve(0x9cC6334F1A7Bc20c9Dde91Db536E194865Af0067, 3);
      // punks.approve(main.thisStorage, 3);
      // main.proposeRaffle('testing a raffle', myAddress, 0, 1, 10, 10, address(punks), 3, 0 ether);
      // vm.stopPrank();
      // main.buyTicket(0);
      // skip(1000);
      // main.executeProposal(0);
      // console.log(main.timeLeft(0));
    }

    //test the delegateTicket function 
    function testDelegate() public {
      //  vm.expectRevert();
       
    }

    
    function testDeposit() public {
      vm.startPrank(myAddress);
      assertGt(punks.balanceOf(myAddress), 1);
      assertEq(punks.ownerOf(3), myAddress);
      punks.approve(0x9cC6334F1A7Bc20c9Dde91Db536E194865Af0067, 3);
      punks.approve(address(main), 3);
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
