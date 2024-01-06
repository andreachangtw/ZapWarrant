// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./Settlement.sol";
import "./WarrantPair.sol";
import "./MockChainlinkAggregator.sol";

contract WarrantFactory {

    // store existing warrant pairs. if not exist, return address(0)
    mapping(address => mapping(address => WarrantPair)) public warrantPairs;

    event SettlementCreated(address settlementAddress);
    event WarrantPairCreated(address warrantPairAddress);

    function getWarrantPair(address _baseToken, address _quoteToken) public view returns (WarrantPair) {
        return warrantPairs[_baseToken][_quoteToken];
    }

    function createWarrantPair(address _baseToken, address _quoteToken) public returns (WarrantPair) {
        require(address(warrantPairs[_baseToken][_quoteToken]) == address(0), "WarrantPair exists");

        Settlement newSettlement = new Settlement(_baseToken, _quoteToken);
        WarrantPair newWarrantPair = new WarrantPair(newSettlement, msg.sender, _baseToken, _quoteToken, new MockChainlinkAggregator());

        warrantPairs[_baseToken][_quoteToken] = newWarrantPair;
        warrantPairs[_quoteToken][_baseToken] = newWarrantPair; // symmetric

        emit SettlementCreated(address(newSettlement));
        emit WarrantPairCreated(address(newWarrantPair));
        return newWarrantPair;
    }
}
