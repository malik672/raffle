// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {RafluxStorage} from "../src/RafluxStorage.sol";

interface CryptoPunks {
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
    CryptoPunks punks = CryptoPunks(0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e);

    // RafluxStorage Rafflux = RafluxStorage();
    function setUp() public {
        Storage = new RafluxStorage();
    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
          .target(token)
          .sig(CryptoPunks(token).balanceOf.selector)
          .with_key(who)
          .checked_write(amt);
    }

    //checks whether it mints
    function testRed() public {
      vm.prank(myAddress);
      writeTokenBalance(myAddress, address(punks), 1000);
      // emit log_named_uint("Current ether balance of myAddress", myAddress.balance);
      // emit log_named_uint("Dai balance of myAddress before", punks.balanceOf(myAddress));
      // emit log_named_uint("Dai balance of myAddress before", punks.balanceOf(myAddress));
    }

    function testDeposit() public {
      vm.prank(myAddress);
      // assertEq(punks.balanceOf(myAddress), 1);
      writeTokenBalance(myAddress, address(punks), 100000);
      emit log_named_address("Dai balance of myAddress before", address(this));
      // assertEq(punks.ownerOf(6000), myAddress);
      // punks.approve(address(Storage), 1);
      // Storage.depositNft(address(punks), 1);
    }

    // function testDeposit() public {};
}
