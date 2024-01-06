// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "interfaces/IWarrant.sol";
import "interfaces/IWarrantPair.sol";

// This contract is used for escrow, return or payment of funds between parties.
contract Settlement is IWarrant, IWarrantPair{

    address public baseToken;
    address public quoteToken;

    // balances of each address
    mapping(address => uint256) public sellerBaseBalances;
    mapping(address => uint256) public sellerQuoteBalances;

    constructor(address _baseToken, address _quoteToken) public {
        baseToken = _baseToken;
        quoteToken = _quoteToken;
    }

    function approveBaseToken(uint256 amount) public returns (bool){
        IERC20(baseToken).approve(address(this), amount);
        return true;
    }

    function approveQuoteToken(uint256 amount) public returns (bool){
        IERC20(quoteToken).approve(address(this), amount);
        return true;
    }

    function escrowCall(Warrant memory warrant) public returns (bool){
        _checkValidTokensForThisVenue(warrant);

        // check allowance
        require(IERC20(baseToken).allowance(warrant.seller, address(this)) >= warrant.baseAmount, "Allowance not enough");

        // update balance
        sellerBaseBalances[warrant.seller] += warrant.baseAmount;

        // safetransfer tokens to this contract
        IERC20(baseToken).transferFrom(warrant.seller, address(this), warrant.baseAmount);

        emit FundsEscrowed(warrant.id, warrant.seller, warrant.buyer, warrant.baseToken, warrant.quoteToken, warrant.warrantType, warrant.strikePrice, warrant.maturity, warrant.baseAmount, warrant.quoteAmount, warrant.premium, warrant.status);

        return true;
    }

    function escrowPut(Warrant memory warrant) public returns (bool){
        _checkValidTokensForThisVenue(warrant);

        // check allowance
        require(IERC20(quoteToken).allowance(warrant.seller, address(this)) >= warrant.quoteAmount, "Allowance not enough");

        // update balance
        sellerQuoteBalances[warrant.seller] += warrant.quoteAmount;

        // safetransfer tokens to this contract
        IERC20(quoteToken).transferFrom(warrant.seller, address(this), warrant.quoteAmount);

        emit FundsEscrowed(warrant.id, warrant.seller, warrant.buyer, warrant.baseToken, warrant.quoteToken, warrant.warrantType, warrant.strikePrice, warrant.maturity, warrant.baseAmount, warrant.quoteAmount, warrant.premium, warrant.status);

        return true;
    }

    function returnCall(Warrant memory warrant) public returns (bool){
        _checkValidTokensForThisVenue(warrant);

        require(sellerBaseBalances[warrant.seller] >= warrant.baseAmount, "Seller base balance not enough");

        // update balance
        sellerBaseBalances[warrant.seller] -= warrant.baseAmount;

        // return base to seller
        IERC20(baseToken).transfer(warrant.seller, warrant.baseAmount);

        emit FundsReleased(warrant.id, warrant.seller, warrant.buyer, warrant.baseToken, warrant.quoteToken, warrant.warrantType, warrant.strikePrice, warrant.maturity, warrant.baseAmount, warrant.quoteAmount, warrant.premium, warrant.status);

        return true;
    }

    function returnPut(Warrant memory warrant) public returns (bool){
        _checkValidTokensForThisVenue(warrant);

        require(sellerQuoteBalances[warrant.seller] >= warrant.quoteAmount, "Seller quote balance not enough");

        // update balance
        sellerQuoteBalances[warrant.seller] -= warrant.quoteAmount;

        // safetransfer tokens to this contract
        IERC20(quoteToken).transfer(warrant.seller, warrant.quoteAmount);

        emit FundsReleased(warrant.id, warrant.seller, warrant.buyer, warrant.baseToken, warrant.quoteToken, warrant.warrantType, warrant.strikePrice, warrant.maturity, warrant.baseAmount, warrant.quoteAmount, warrant.premium, warrant.status);

        return true;
    }

    function buyWarrant(Warrant memory warrant, address attemptBuyer) public returns (bool){
        _checkValidTokensForThisVenue(warrant);

        // check allowance
        require(IERC20(quoteToken).allowance(attemptBuyer, address(this)) >= warrant.premium, "Allowance not enough");

        // pay premium to seller
        IERC20(quoteToken).transferFrom(attemptBuyer, warrant.seller, warrant.premium);

        return true;
    }

    function exerciseCallActual(Warrant memory warrant) public returns (bool){
        _checkValidTokensForThisVenue(warrant);

        // check allowance
        require(IERC20(quoteToken).allowance(warrant.buyer, address(this)) >= warrant.quoteAmount, "Buyer allowance not enough");

        // seller pay base to buyer
        require(sellerBaseBalances[warrant.seller] >= warrant.baseAmount, "Seller base balance not enough");
        sellerBaseBalances[warrant.seller] -= warrant.baseAmount;
        IERC20(baseToken).transfer(warrant.buyer, warrant.baseAmount);

        // buyer pay quote to seller
        IERC20(quoteToken).transferFrom(warrant.buyer, warrant.seller, warrant.quoteAmount);

        return true;
    }

    function exercisePutActual(Warrant memory warrant) public returns (bool){
        _checkValidTokensForThisVenue(warrant);

        // check allowance
        require(IERC20(baseToken).allowance(warrant.buyer, address(this)) >= warrant.baseAmount, "Buyer allowance not enough");

        // seller pay quote to buyer
        require(sellerQuoteBalances[warrant.seller] >= warrant.quoteAmount, "Seller quote balance not enough");
        sellerQuoteBalances[warrant.seller] -= warrant.quoteAmount;
        IERC20(quoteToken).transfer(warrant.buyer, warrant.quoteAmount);

        // buyer pay base to seller
        IERC20(baseToken).transferFrom(warrant.buyer, warrant.seller, warrant.baseAmount);

        return true;
    }

    function exerciseCallCash(Warrant memory warrant, uint256 latestPrice) public returns (bool){
        _checkValidTokensForThisVenue(warrant);

        // calculate settle amount
        uint256 settleAmount = (latestPrice - warrant.strikePrice) / latestPrice * warrant.baseAmount;

        // pay settleAmount to buyer and return the rest to seller
        require(sellerBaseBalances[warrant.seller] >= warrant.baseAmount, "Seller base balance not enough");
        sellerBaseBalances[warrant.seller] -= settleAmount;
        IERC20(baseToken).transfer(warrant.buyer, settleAmount);
        uint256 returnAmount = warrant.baseAmount - settleAmount;
        sellerBaseBalances[warrant.seller] -= returnAmount;
        IERC20(baseToken).transfer(warrant.seller, returnAmount);

        return true;
    }

    function exercisePutCash(Warrant memory warrant, uint256 latestPrice) public returns (bool){
        _checkValidTokensForThisVenue(warrant);

        // calculate settle amount
        uint256 settleAmount = (warrant.strikePrice - latestPrice) * warrant.baseAmount;

        // pay settleAmount to buyer and return the rest to seller
        require(sellerQuoteBalances[warrant.seller] >= warrant.quoteAmount, "Seller quote balance not enough");
        sellerQuoteBalances[warrant.seller] -= settleAmount;
        IERC20(quoteToken).transfer(warrant.buyer, settleAmount);
        uint256 returnAmount = warrant.quoteAmount - settleAmount;
        sellerQuoteBalances[warrant.seller] -= returnAmount;
        IERC20(quoteToken).transfer(warrant.seller, returnAmount);

        return true;
    }

    function _checkValidTokensForThisVenue(Warrant memory warrant) internal view returns (bool){
        require(warrant.baseToken == baseToken && warrant.quoteToken == quoteToken, "Wrong settlement venue");
        return true;
    }
}
