// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import {stdError} from "forge-std/Test.sol";
import {RaffluxDao} from "../src/RaffluxDao.sol";
import {RaffluxMain} from "../src/RaffluxMain.sol";
import {RaffluxValidator} from "../src/RaffluxValidator.sol";

//this a custom nft created on the polygon testnet used to test this
interface myNfts {
    function balanceOf(address) external view returns (uint256);
    function approve(address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract RaffluxTest is Test {
    RaffluxDao rafflux;
    RaffluxMain main;
    RaffluxValidator validator;
    address public address1;
    address public address2;
    using stdStorage for StdStorage;
    address constant myAddress = 0x30bE4D758d86cfb1Ae74Ae698f2CF4BA7dC8d693;
    myNfts punks = myNfts(0x2690080D83460264424BcAB8ceE6afFAbCD6b933);

    
    function setUp() public {
        rafflux = new RaffluxDao();
        main = new RaffluxMain();
        validator = new RaffluxValidator();
    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
          .target(token)
          .sig(myNfts(token).balanceOf.selector)
          .with_key(who)
          .checked_write(amt);
    }

    function writeProposal(uint256 _proposalId) internal {
      stdstore
        .target(address(main))
        .sig(main.buyersOf.selector)
        .with_key(_proposalId)
        .checked_write(address(0));
    }

    //checks whether it starts a raffle
    function testRaffleStartProposal() public {
      testDeposit();
      vm.startPrank(myAddress);
      main.proposeRaffle('testing a raffle', myAddress, block.timestamp, block.timestamp + 1000, 10, 10, address(punks), 3, 0 ether);
      vm.stopPrank();
    }

    //checks whether the proposal is valid for execution
    function testExecuteProposal() public {
      testDeposit();
      vm.startPrank(myAddress);
      // punks.approve(address(main), 3);
      // punks.approve(0x9cC6334F1A7Bc20c9Dde91Db536E194865Af0067, 3);
      // punks.approve(main.thisStorage, 3);
      main.proposeRaffle('testing a raffle', myAddress, 0, 1, 10, 10, address(punks), 3, 0 ether);
      main.buyTicket(0);
      vm.stopPrank();
      skip(1000); 
      console.log(punks.ownerOf(3));
      // vm.startPrank(address(main));
      // main.executeProposal(0);
      vm.stopPrank();
      
    }

    //test the delegateTicket function 
    function testDelegate() public {
      //  vm.expectRevert();
       
    }

    
    function testDeposit() public {
      vm.startPrank(myAddress);
      assertGt(punks.balanceOf(myAddress), 1);
      assertEq(punks.ownerOf(3), myAddress);
      punks.approve(address(main), 3);
      // Storage.depositNft(address(punks), 4, 0);
      vm.stopPrank();
    }

    //test points 
    // function testUpdatePointExpectedRevert() public {
    //   // vm.expectRevert("can't be zero");
    //   vm.prank(address(main));
    //   //check it add points
    //   assertEq(main.viewPoints(myAddress, 0), 10);
    //   //check it removes points
    //   //the two(2) here is useless since the remove points remove all points a user has and equate it to zero
    //   main.updatePoints(myAddress, 10,0, false);
    //   // //check if point equal to zero after removal
    //   assertEq(main.viewPoints(myAddress,0), 0);      
    // }

    function testAddValidator() public {
       validator.addValidators();
       assertEq(validator.checkValidator(), true);
    }

    function testAddValidatorsTwice() public {
       validator.addValidators();
       validator.addValidators();
       vm.expectRevert("already a validator");
    }

    function testFuzzValidators() public {
      validator.addValidators();
      vm.startPrank(address(0));
      validator.addValidators();
      vm.stopPrank();
      vm.startPrank(address(1));
      validator.addValidators();
      vm.stopPrank();
      vm.startPrank(address(2));
      validator.addValidators();
      vm.stopPrank();
      vm.startPrank(address(3));
      validator.addValidators();
      vm.stopPrank();
      vm.startPrank(address(4));
      validator.addValidators();
      vm.stopPrank();
      vm.startPrank(address(5));
      validator.addValidators();
      vm.stopPrank();
      vm.startPrank(address(6));
      validator.addValidators();
      vm.stopPrank();
    }

    function testRemoveAllValidators() public {
      testFuzzValidators();
      validator.returnValidators();
      validator.removeAllValidator();
      validator.returnValidators();
    }

    function testValidatorProposal() public {

    }

    function testValidatorDeposit() public {
      vm.startPrank(myAddress);
      assertGt(punks.balanceOf(myAddress), 1);
      assertEq(punks.ownerOf(3), myAddress);
      punks.approve(address(validator), 3);
      // Storage.depositNft(address(punks), 4, 0);
      vm.stopPrank();
    }

    function testValidatorBuyTicketMinTicket() public {
      testValidatorDeposit();
      testValidatorProposeRaffle(0);
      validator.buyTicket(0);
      vm.expectRevert("maximum ticket reached");
      validator.buyTicket(0);
    }

    function testValidatorBuyTicketMaxTicket() public {
      testValidatorDeposit();
      testValidatorProposeRaffle(10);
      validator.buyTicket(0);
    }



    function testValidatorProposeRaffle(uint256 _ticket) public {
        testValidatorDeposit();
        vm.startPrank(myAddress);
        validator.proposeRaffle('testing a raffle', msg.sender, 0, 1, _ticket, 10, address(punks), 3, 0 ether);
        console.log(punks.ownerOf(3));
        vm.stopPrank();
    }

    function testStopProposal() public {
        testValidatorProposeRaffle(0);
        vm.startPrank(myAddress);
        validator.addValidators();
        validator.changeProposalStatus(1);
        validator.buyTicket(0); 
        vm.expectRevert("should revert since proposal has stopped");
        vm.stopPrank();
        console.log( validator.returnMainAddress());
    }

    function testContinueProposal() public {
      testStopProposal();
      vm.startPrank(myAddress);
      validator.changeProposalStatus(0);
      validator.buyTicket(0); 
      vm.stopPrank();
    }

    function testProposalDao() public {
      rafflux.startProposal(msg.sender, "we need to stop proposal 3, its a scam", _voteFor, _voteAgainst, _raffleId, _functionId);
    }
}
