// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./chainlinkInterface.sol";
contract PriceConsumerV3 {
    AggregatorV3Interface internal ETHpriceFeed;
    /**
     * Network: Mumbai Testnet
     * ETH/USD Address: 0x0715A7794a1dc8e42615F059dD6e406A6594651A
     */
    constructor() {
        ETHpriceFeed = AggregatorV3Interface(0x0715A7794a1dc8e42615F059dD6e406A6594651A);
    }
    /**
     * Returns the latest prices
     */
    function LatestETHprice() public view returns (uint80,int) {
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = ETHpriceFeed.latestRoundData();
        return (roundID,price);
    }
}
