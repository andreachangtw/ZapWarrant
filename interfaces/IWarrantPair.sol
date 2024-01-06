// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "../interfaces/IWarrant.sol";

interface IWarrantPair {
    // events
    event WarrantListed(uint256 warrantId, address seller, address buyer, address baseToken, address quoteToken, IWarrant.WarrantType warrantType, uint256 strikePrice, uint256 maturity, uint256 baseAmount, uint256 quoteAmount, uint256 premium, IWarrant.WarrantStatus status);
    event WarrantCanceled(uint256 warrantId, address seller, address buyer, address baseToken, address quoteToken, IWarrant.WarrantType warrantType, uint256 strikePrice, uint256 maturity, uint256 baseAmount, uint256 quoteAmount, uint256 premium, IWarrant.WarrantStatus status);
    event WarrantSold(uint256 warrantId, address seller, address buyer, address baseToken, address quoteToken, IWarrant.WarrantType warrantType, uint256 strikePrice, uint256 maturity, uint256 baseAmount, uint256 quoteAmount, uint256 premium, IWarrant.WarrantStatus status);
    event WarrantExercised(uint256 warrantId, address seller, address buyer, address baseToken, address quoteToken, IWarrant.WarrantType warrantType, uint256 strikePrice, uint256 maturity, uint256 baseAmount, uint256 quoteAmount, uint256 premium, IWarrant.WarrantStatus status);
    event WarrantExpired(uint256 warrantId, address seller, address buyer, address baseToken, address quoteToken, IWarrant.WarrantType warrantType, uint256 strikePrice, uint256 maturity, uint256 baseAmount, uint256 quoteAmount, uint256 premium, IWarrant.WarrantStatus status);
    event FundsEscrowed(uint256 warrantId, address seller, address buyer, address baseToken, address quoteToken, IWarrant.WarrantType warrantType, uint256 strikePrice, uint256 maturity, uint256 baseAmount, uint256 quoteAmount, uint256 premium, IWarrant.WarrantStatus status);
    event FundsReleased(uint256 warrantId, address seller, address buyer, address baseToken, address quoteToken, IWarrant.WarrantType warrantType, uint256 strikePrice, uint256 maturity, uint256 baseAmount, uint256 quoteAmount, uint256 premium, IWarrant.WarrantStatus status);
}