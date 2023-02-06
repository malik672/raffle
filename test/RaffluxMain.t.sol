// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "./utils/Console.sol";
import {stdError} from "forge-std/Test.sol";
import {RaffluxMain} from "../src/RaffluxMain.sol";

//this a custom nft created on the polygon testnet used to test this
interface myNfts {
    function balanceOf(address) external view returns (uint256);
    function approve(address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract RaffluxMainTest is Test, RaffluxMain {
    // Cheats constant cheats = Cheats(HEVM_ADDRESS);
    RaffluxMain main;
    address public address1;
    address public address2;
    //address of tester, this can be any address
    address constant myAddress = 0x30bE4D758d86cfb1Ae74Ae698f2CF4BA7dC8d693;
    //address of test nft on polygon mumbai
    myNfts punks = myNfts(0x2690080D83460264424BcAB8ceE6afFAbCD6b933);

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        main = new RaffluxMain();
    }

    /*//////////////////////////////////////////////////////////////
                       NFTS
    //////////////////////////////////////////////////////////////*/

    ///@notice  approve token for transfer
    function testTokenApprovalERC721() public {
        vm.startPrank(myAddress);
        assertGt(punks.balanceOf(myAddress), 1);
        assertEq(punks.ownerOf(1), myAddress);
        punks.approve(address(main), 1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               RAFFLE TEST
    //////////////////////////////////////////////////////////////*/

    ///@notice  this is to check whether a raffle initialized, should be successful
    ///@param _value this is the value to specify the price of a ticket
    function testProposeStartRaffleUsingERC721token(uint256 _value) public {
        //approve token before proposing raffle
        testTokenApprovalERC721();
        vm.startPrank(myAddress);
        //start raffle proposal
        main.proposeRaffle(
            "raffle to start a fundraiser for the red famil", //description
            myAddress, //address of raffle creator
            uint64(block.timestamp), //starting time of raffle
            uint64(block.timestamp + 10000), //ending time of raffle
            10, //maximum ticket allocated for the raffle
            5, //maximum ticket per user
            address(punks), //address of token to be used for raffle
            1, //token id of particular token
            _value //price per raffle ticket
        );
        vm.stopPrank();
        //first raffle should start at index 0
        assertEq(main.startIndex(), 0);
        assertTrue(main.isActive(0));
    }

    ///@notice  this is to check whether index initialized
    function testStartIndexIncrement() public {
        //start first proposal
        testProposeStartRaffleUsingERC721token(0);

        vm.startPrank(myAddress);
        //approve tokenId 3
        punks.approve(address(main), 3);
        main.proposeRaffle(
            "raffle to start a fundraiser for the red famil", //description
            myAddress, //address of raffle creator
            uint64(block.timestamp), //starting time of raffle
            uint64(block.timestamp + 10000), //ending time of raffle
            100, //maximum ticket allocated for the raffle
            5, //maximum ticket per user
            address(punks), //address of token to be used for raffle
            3, //token id of particular token
            0 ether //price per raffle ticket
        );
        assertEq(main.startIndex(), 1);
        assertGt(main.startIndex(), 0);
        vm.stopPrank();
    }

    ///@notice testRaffle proposal when the starting time is greater than the end time, should revert
    function testProposeStartRaffleTime() public {
        vm.expectRevert(
            abi.encodeWithSelector(RaffluxMain.transactReverted.selector, "start time can't be greater than end time")
        );
        //start raffle proposal
        main.proposeRaffle(
            "raffle to start a fundraiser for the red famil", //description
            myAddress, //address of raffle creator
            uint64(block.timestamp), //starting time of raffle
            uint64(block.timestamp - 10000), //ending time of raffle
            100, //maximum ticket allocated for the raffle
            1, //maximum ticket per user
            address(punks), //address of token to be used for raffle
            3, //token id of particular token
            1 ether //price per raffle ticket
        );
        vm.stopPrank();
    }

    ///@notice Test buyTicket when raffle is initialized
    function testBuyTicket() public {
        vm.deal(myAddress, 2 ether);
        //this initializes a succesful raffle and assumes raffleId is now 0
        testProposeStartRaffleUsingERC721token(0);
        //buys ticket
        vm.startPrank(myAddress);
        //buy ticket using 1 ether
        // (bool status, bytes memory data) =
        //     address(main).call{value: 1 ether, gas: 200000000}(abi.encodeWithSignature("buyTicket(uint256)", 0));
        // require(status);
        main.buyTicket(0);
        assertGt(main.totalTicket(myAddress), 0);
        assertTrue(main.isActive(0));
        assertTrue(main.hasTicket(0, myAddress));
        assertGt(main.totalUserTicket(0, myAddress), 0);
        assertGt(main.totalSupply(0), 0);
        assertGt(main.maximumUserTicket(0, myAddress), 0);
        assertGt(address(main).balance, 0.99 ether);
        vm.stopPrank();
    }

    ///@notice testBuyTicketWithAaValidRaffleIdWithInsufficientFunds with ether less than required price should revert
    function testBuyTicketWithAaValidRaffleIdWithInsufficientFunds() public {
        //this initializes a succesful raffle and assumes raffleId is now 0
        testProposeStartRaffleUsingERC721token(1);
        //should revert
        vm.expectRevert(abi.encodeWithSelector(RaffluxMain.transactReverted.selector, "Insufficent Funds"));
        //buys ticket
        main.buyTicket(0);
    }

    ///@notice testBuyTicketExceedMaximumTicketPerUser, when user has already reached maximum ticket, should revert
    function testBuyTicketExceedMaximumTicketPerUser() public {
        vm.deal(myAddress, 200 ether);
        //this initializes a succesful raffle and assumes raffleId is now 0
        
        testProposeStartRaffleUsingERC721token(0);
        vm.startPrank(myAddress);
        //maximum ticket per user based on this is 5
        main.buyTicket(0); //1
        main.buyTicket(0); //2
        main.buyTicket(0); //3
        main.buyTicket(0); //4
        main.buyTicket(0); //5
        vm.expectRevert(abi.encodeWithSelector(RaffluxMain.transactReverted.selector, "maximum ticket reached"));
        main.buyTicket(0); //6
        vm.stopPrank();
    }

    ///@notice  testBuyTicketExceedMaximumRaffleTicket, when raffles has already reached maximum ticket, should revert
    function testBuyTicketExceedMaximumRaffleTicket() public {
        //this initializes a succesful raffle and assumes raffleId is now 0
        testProposeStartRaffleUsingERC721token(0);
        //maximum ticket for this raffle is 10
        main.buyTicket(0); //1
        vm.startPrank(address(0));
        main.buyTicket(0); //2
        main.buyTicket(0); //3
        main.buyTicket(0); //4
        vm.stopPrank();
        main.buyTicket(0); //5
        vm.startPrank(address(1));
        main.buyTicket(0); //6
        main.buyTicket(0); //7
        main.buyTicket(0); //8
        vm.stopPrank();
        vm.startPrank(address(2));
        main.buyTicket(0); //9
        main.buyTicket(0); //10
        vm.stopPrank();

        vm.startPrank(address(3));
        vm.expectRevert(
            abi.encodeWithSelector(RaffluxMain.transactReverted.selector, "maximum ticket reached for this raffle")
        );
        main.buyTicket(0); //11
        vm.stopPrank();
    }

    ///@notice startProposal should add ten points whenever a user starts a proposal, myAddress was used throughout
    function checkAddPointsOnBuyTicketAndStartProposal() public {
        //this initializes a succesful raffle and assumes raffleId is now 0
        //each additional point is done buy adding 10
        testProposeStartRaffleUsingERC721token(0);
        console.log(main.viewPoints(myAddress, 0));
        assertGt(main.viewPoints(myAddress, 0), 0);
        assertEq(main.viewPoints(myAddress,0), 10);

        //chcek for buyTicket
        vm.startPrank(myAddress);
        main.buyTicket(0);
        assertGt(main.viewPoints(myAddress, 0), 10);
        assertEq(main.viewPoints(myAddress,0), 20);
        vm.stopPrank();
    }

    function testDelegateTicket() public {

    }
}
