// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "../interfaces/IWarrant.sol";
import "../interfaces/IWarrantPair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Settlement.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./MockChainlinkAggregator.sol";

contract WarrantPair is IWarrant, IWarrantPair{

    // AggregatorV3Interface internal priceFeed;
    MockChainlinkAggregator internal mockPriceFeed;

    address public admin;
    mapping(uint256 => Warrant) public warrants;
    uint256 public lastWarrantId = 0;
    Settlement public settlement;
    address public baseToken;
    address public quoteToken;

    constructor(Settlement _settlement, address _admin, address _baseToken, address _quoteToken, MockChainlinkAggregator _mockPriceFeed) public {
        settlement = _settlement;
        admin = _admin;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        // priceFeed = AggregatorV3Interface(_priceFeed);
        mockPriceFeed = _mockPriceFeed;
    }

    function sellWarrant( 
        WarrantType warrantType,
        uint256 strikePrice,
        uint256 maturity,
        uint256 baseAmount,
        uint256 premium) external returns (bool) {


        // new a warrant
        uint256 warrantId = lastWarrantId + 1;
        Warrant memory warrant = Warrant({
            id: warrantId,
            seller: msg.sender,
            buyer: address(0),
            baseToken: baseToken,
            quoteToken: quoteToken,
            warrantType: warrantType,
            strikePrice: strikePrice,
            maturity: maturity,
            baseAmount: baseAmount,
            quoteAmount: strikePrice * baseAmount / (10 ** ERC20(baseToken).decimals()),
            premium: premium,
            isCashSettled: false,
            status: WarrantStatus.INIT
        }); 
        
        // call warrant
        if (warrantType == WarrantType.CALL) {     
            // check seller has enough base balance
            require(IERC20(baseToken).balanceOf(msg.sender) >= baseAmount, "Seller base balance not enough");

            // escrow base token
            bool success = settlement.escrowCall(warrant);
            require(success, "Escrow call failed");
        } else if (warrantType == WarrantType.PUT) {
            // check seller has enough quote balance
            require(IERC20(quoteToken).balanceOf(msg.sender) >= warrant.quoteAmount, "Seller quote balance not enough");

            // escrow quote token
            bool success = settlement.escrowPut(warrant);
            require(success, "Escrow put failed"); 
        } else {
            revert("Warrant type not correct");
        }

        // add warrant to warrants
        warrant.status = WarrantStatus.ACTIVE;
        warrants[warrantId] = warrant;
        lastWarrantId = warrantId;

        emit WarrantListed(warrantId, msg.sender, address(0), baseToken, quoteToken, warrantType, strikePrice, maturity, baseAmount, warrant.quoteAmount, premium, WarrantStatus.ACTIVE);

        return true;
    }

    function buyWarrant(uint256 warrantId) public returns (bool) {
        Warrant memory warrant = getWarrant(warrantId);

        // warrant status should be active
        require(warrant.status == WarrantStatus.ACTIVE, "Warrant not available for selling");

        // call
        if(warrant.warrantType == WarrantType.CALL || warrant.warrantType == WarrantType.PUT) {
            // check buyer has enough quote balance
            require(IERC20(quoteToken).balanceOf(msg.sender) >= warrant.premium, "Buyer quote balance not enough");

            // use settlement contract to buy and check if success
            bool success = settlement.buyWarrant(warrant, msg.sender);
            require(success, "Buy warrant failed");
        } else {
            revert("Warrant type not correct");
        }

        // update warrant
        warrant.buyer = msg.sender;
        warrant.status = WarrantStatus.SOLD;
        warrants[warrantId] = warrant;

        emit WarrantSold(warrantId, warrant.seller, msg.sender, baseToken, quoteToken, warrant.warrantType, warrant.strikePrice, warrant.maturity, warrant.baseAmount, warrant.quoteAmount, warrant.premium, WarrantStatus.SOLD);

        return true;
    }

    function cancelWarrant(uint256 warrantId) public returns (bool) {
        Warrant memory warrant = getWarrant(warrantId);

        // warrant status should be active
        require(warrant.status == WarrantStatus.ACTIVE, "Warrant not eligible for cancel");

        // check sender is seller
        require(warrant.seller == msg.sender, "Sender not seller");

        // call
        if(warrant.warrantType == WarrantType.CALL) {
            // use settlement contract to return and check if success
            bool success = settlement.returnCall(warrant);
            require(success, "Return call failed");
        } else if (warrant.warrantType == WarrantType.PUT) {
            // use settlement contract to return and check if success
            bool success = settlement.returnPut(warrant);
            require(success, "Return put failed");
        } else {
            revert("Warrant type not correct");
        }

        // update warrant
        warrant.status = WarrantStatus.CANCELED;
        warrants[warrantId] = warrant;

        emit WarrantCanceled(warrantId, msg.sender, address(0), baseToken, quoteToken, warrant.warrantType, warrant.strikePrice, warrant.maturity, warrant.baseAmount, warrant.quoteAmount, warrant.premium, WarrantStatus.CANCELED);

        return true;
    }

    function exerciseWarrant(uint256 warrantId, bool _isCashSettled) public returns (bool) {
        Warrant memory warrant = getWarrant(warrantId);

        // warrant status should be sold
        require(warrant.status == WarrantStatus.SOLD, "Warrant not eligible for exercise");

        // warrant should be mature but not over (maturity + 1) day
        require(block.timestamp >= warrant.maturity && block.timestamp < warrant.maturity + 1 days, "Warrant not mature or expired");

        // check buyer and seller not empty
        require(warrant.buyer != address(0) && warrant.seller != address(0), "Buyer or seller not exist");

        // check sender is buyer
        require(warrant.buyer == msg.sender, "Sender not buyer");

        uint256 latestPrice = _getLatestPrice();

        if(warrant.warrantType == WarrantType.CALL) {
            if(_isCashSettled) {
                if(_isInTheMoney(warrant, latestPrice)) {
                    // use settlement contract to exercise and check if success
                    bool success = settlement.exerciseCallCash(warrant, latestPrice);
                    require(success, "Exercise call failed");
                } else {
                    // out of money, return call
                    bool success = settlement.returnCall(warrant);
                    require(success, "Return call failed");
                }
                warrant.isCashSettled = true;
            } else {
                // use settlement contract to exercise and check if success
                bool success = settlement.exerciseCallActual(warrant);
                require(success, "Exercise call failed");
            }
        } else if (warrant.warrantType == WarrantType.PUT) {
            if(_isCashSettled) {
                if(_isInTheMoney(warrant, latestPrice)) {
                    // use settlement contract to exercise and check if success
                    bool success = settlement.exercisePutCash(warrant, latestPrice);
                    require(success, "Exercise put failed");
                } else {
                    // out of money, return put
                    bool success = settlement.returnPut(warrant);
                    require(success, "Return put failed");
                }
                warrant.isCashSettled = true;
            } else {
                // use settlement contract to exercise and check if success
                bool success = settlement.exercisePutActual(warrant);
                require(success, "Exercise put failed");
            }
        } else {
            revert("Warrant type not correct");
        }

        // update warrant
        warrant.status = WarrantStatus.EXERCISED;
        warrants[warrantId] = warrant;

        emit WarrantExercised(warrantId, warrant.seller, warrant.buyer, baseToken, quoteToken, warrant.warrantType, warrant.strikePrice, warrant.maturity, warrant.baseAmount, warrant.quoteAmount, warrant.premium, WarrantStatus.EXERCISED);

        return true;
    }

    function expireWarrant(uint256 warrantId) public returns (bool) {
        Warrant memory warrant = getWarrant(warrantId);

        // warrant should be active and mature or sold and already pass maturity + 1 day
        require(
            (warrant.status == WarrantStatus.ACTIVE && block.timestamp >= warrant.maturity) || 
            (warrant.status == WarrantStatus.SOLD && block.timestamp >= warrant.maturity + 1 days), 
            "Warrant not eligible for expire"
        );

        // call
        if(warrant.warrantType == WarrantType.CALL) {
            // use settlement contract to return and check if success
            bool success = settlement.returnCall(warrant);
            require(success, "Return call failed");
        } else if (warrant.warrantType == WarrantType.PUT) {
            // use settlement contract to return and check if success
            bool success = settlement.returnPut(warrant);
            require(success, "Return put failed");
        } else {
            revert("Warrant type not correct");
        }

        // update warrant
        warrant.status = WarrantStatus.EXPIRED;
        warrants[warrantId] = warrant;

        emit WarrantExpired(warrantId, warrant.seller, warrant.buyer, baseToken, quoteToken, warrant.warrantType, warrant.strikePrice, warrant.maturity, warrant.baseAmount, warrant.quoteAmount, warrant.premium, WarrantStatus.EXPIRED);

        return true;
    }

    function getWarrants() public view returns (Warrant[] memory) {
        Warrant[] memory result = new Warrant[](lastWarrantId);
        for (uint256 i = 1; i <= lastWarrantId; i++) {
            result[i - 1] = warrants[i];
        }
        return result;
    }

    function getWarrant(uint256 warrantId) public view returns (Warrant memory) {
        require(warrants[warrantId].id != 0, "Warrant not exist");
        return warrants[warrantId];
    }

    function _getLatestPrice() internal view returns (uint256) {
        // (,int price,,,) = priceFeed.latestRoundData();
        // price is multiplied by priceFeed.decimals()

        // mock price feed and convert to quote token decimals
        (,int tempPrice,,,) = mockPriceFeed.latestRoundData();
        uint256 price = uint256(tempPrice) * (10 ** ERC20(quoteToken).decimals()) / (10 ** mockPriceFeed.decimals());
        return uint256(price);
    }

    function _isInTheMoney(Warrant memory warrant, uint256 latestPrice) internal view returns (bool) {
        if(warrant.warrantType == WarrantType.CALL) {
            return warrant.strikePrice < latestPrice;
        } else if (warrant.warrantType == WarrantType.PUT) {
            return warrant.strikePrice > latestPrice;
        } else {
            revert("Warrant type not correct");
        }
    }

}