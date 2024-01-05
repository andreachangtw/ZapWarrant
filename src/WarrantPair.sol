// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "../interfaces/IWarrant.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Settlement.sol";

contract WarrantPair is IWarrant{

    address public admin;
    mapping(uint256 => Warrant) public warrants;
    uint256 public lastWarrantId = 0;
    Settlement public settlement;
    address public baseToken;
    address public quoteToken;

    constructor(Settlement _settlement, address _admin, address _baseToken, address _quoteToken) public {
        settlement = _settlement;
        admin = _admin;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
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
        warrant.status = WarrantStatus.EXPIRED;
        warrants[warrantId] = warrant;

        return true;
    }

    function exerciseWarrant(uint256 warrantId) public returns (bool) {
        Warrant memory warrant = getWarrant(warrantId);

        // warrant status should be sold
        require(warrant.status == WarrantStatus.SOLD, "Warrant not eligible for exercise");

        // warrant should be mature but not over (maturity + 1) day
        require(block.timestamp >= warrant.maturity, "Warrant not mature");
        require(block.timestamp < warrant.maturity + 1 days, "Warrant expired");

        // check buyer and seller not empty
        require(warrant.buyer != address(0), "Buyer not exist");
        require(warrant.seller != address(0), "Seller not exist");

        // check sender is buyer
        require(warrant.buyer == msg.sender, "Sender not buyer");

        // call
        if(warrant.warrantType == WarrantType.CALL) {
            // use settlement contract to exercise and check if success
            bool success = settlement.exerciseCall(warrant);
            require(success, "Exercise call failed");
        } else if (warrant.warrantType == WarrantType.PUT) {
            // use settlement contract to exercise and check if success
            bool success = settlement.exercisePut(warrant);
            require(success, "Exercise put failed");
        } else {
            revert("Warrant type not correct");
        }

        // update warrant
        warrant.status = WarrantStatus.EXERCISED;
        warrants[warrantId] = warrant;

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

        // check sender is admin
        require(msg.sender == admin, "Sender not admin");

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

}