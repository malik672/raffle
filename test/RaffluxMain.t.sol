// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {RaffluxMain} from "../src/RaffluxMain.sol";

//this a custom nft created on the polygon testnet used to test this
interface myNfts {
    function balanceOf(address) external view returns (uint256);
    function approve(address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract RaffluxMainTest is Test, RaffluxMain {
    // Vm internal immutable vm = Vm(HEVM_ADDRESS);
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
        assertEq(punks.ownerOf(3), myAddress);
        punks.approve(address(main), 3);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               RAFFLE TEST
    //////////////////////////////////////////////////////////////*/

    ///@notice  this is to check whether a raffle initialized
    function testProposeStartRaffleUsingERC721token() public {
        //approve token before proposing raffle
        testTokenApprovalERC721();
        vm.startPrank(myAddress);
        //start raffle proposal
        main.proposeRaffle(
            "raffle to start a fundraiser for the red famil", //description
            myAddress, //address of raffle creator
            uint64(block.timestamp), //starting time of raffle
            uint64(block.timestamp + 10000), //ending time of raffle
            100, //maximum ticket allocated for the raffle
            1, //maximum ticket per user
            address(punks), //address of token to be used for raffle
            3, //token id of particular token
            1 ether //price per raffle ticket
        );
        vm.stopPrank();
    }

    ///@notice testRaffle proposal when the starting time is greater than the end time, should revert
    function testProposeStartRaffleTime() public {
        vm.expectRevert(abi.encodeWithSelector(RaffluxMain.transactReverted.selector, "start time can't be greater than end time"));
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
}
