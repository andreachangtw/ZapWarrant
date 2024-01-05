// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IWarrant {
    enum WarrantType { CALL, PUT }
    enum WarrantStatus { INIT, ACTIVE, SOLD, EXPIRED, EXERCISED }
    struct Warrant {
        uint256 id;
        address seller;
        address buyer;
        address baseToken;
        address quoteToken;
        WarrantType warrantType;
        uint256 strikePrice;
        uint256 maturity;
        uint256 baseAmount;
        uint256 quoteAmount;
        uint256 premium;
        WarrantStatus status;
    }
}