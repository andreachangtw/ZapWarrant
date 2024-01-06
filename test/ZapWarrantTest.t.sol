// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Settlement} from "src/Settlement.sol";
import {WarrantPair} from "src/WarrantPair.sol";
import {IWarrant} from "interfaces/IWarrant.sol";
import {MockChainlinkAggregator} from "src/MockChainlinkAggregator.sol";
import {WarrantFactory} from "src/WarrantFactory.sol";

contract MyToken is ERC20 {
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
    {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
}

contract ZapWarrantTest is Test, IWarrant {
    address public admin;
    address public seller;
    address public buyer;
    address public buyer2;

    // address public UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    // address public USDT = 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06;

    // create 2 fake tokens
    MyToken UNI = new MyToken("UNI", "UNI");
    MyToken USDT = new MyToken("USDT", "USDT");

    WarrantFactory public factory;
    MockChainlinkAggregator mockPriceFeed;
    Settlement public settlement;
    WarrantPair public pair;

    function setUp() public {
        admin = address(this);
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        buyer2 = makeAddr("buyer2");

        factory = new WarrantFactory();
        if (factory.getWarrantPair(address(UNI), address(USDT)) == WarrantPair(address(0))) {
            pair = factory.createWarrantPair(address(UNI), address(USDT), new MockChainlinkAggregator());
        } else {
            pair = factory.getWarrantPair(address(UNI), address(USDT));
        }

        settlement = pair.settlement();
        mockPriceFeed = pair.mockPriceFeed();

        // deal seller some UNI and USDT
        deal(address(UNI), seller, 10 * 10 ** UNI.decimals());
        deal(address(USDT), seller, 100 * 10 ** USDT.decimals());

        // deal buyer some UNI and USDT
        deal(address(UNI), buyer, 10 * 10 ** UNI.decimals());
        deal(address(USDT), buyer, 100 * 10 ** USDT.decimals());

        // deal buyer2 some UNI and USDT
        deal(address(UNI), buyer2, 10 * 10 ** UNI.decimals());
        deal(address(USDT), buyer2, 100 * 10 ** USDT.decimals());
    }

    function test_sellCall() public {
        // happy case
        _sellCall(5, 1, 12);

        // revert case
        IWarrant.WarrantType warrantType = IWarrant.WarrantType.CALL;
        uint256 strikePrice = 5 * 10 ** USDT.decimals();
        uint256 maturity = block.timestamp + 7 days;
        uint256 baseAmount = 100 * 10 ** UNI.decimals();
        uint256 premium = 12 * 10 ** USDT.decimals() / 10;

        vm.startPrank(seller);
        // allow settlement to spend baseAmount
        UNI.approve(address(settlement), baseAmount); 
        vm.expectRevert("Seller base balance not enough");
        pair.sellWarrant(warrantType, strikePrice, maturity, baseAmount, premium);
        vm.stopPrank();
    }

    function test_buyCall() public {
        uint256 warrantId = _sellCall(5, 1, 12);

        // happy case
        vm.startPrank(buyer);
        // allow settlement to spend premium and quoteAmount
        USDT.approve(address(settlement), pair.getWarrant(warrantId).premium + pair.getWarrant(warrantId).quoteAmount);
        pair.buyWarrant(warrantId);
        vm.stopPrank();

        // revert case: another buyer try to buy the same warrant
        vm.startPrank(buyer2);
        USDT.approve(address(settlement), pair.getWarrant(warrantId).premium + pair.getWarrant(warrantId).quoteAmount);
        vm.expectRevert("Warrant not available for selling");
        pair.buyWarrant(warrantId);
        vm.stopPrank();
    }

    function test_exerciseCallActual() public {
        test_buyCall();

        // revert case: buyer try to exercise before maturity
        vm.startPrank(buyer);
        vm.expectRevert("Warrant not mature or expired");
        pair.exerciseWarrant(1, false);
        vm.stopPrank();

        // revert case: another buyer try to exercise
        _forwardDays(7);
        vm.startPrank(buyer2);
        vm.expectRevert("Sender not buyer");
        pair.exerciseWarrant(1, false);
        vm.stopPrank();

        // happy case
        // _forwardDays(7);
        vm.startPrank(buyer);
        pair.exerciseWarrant(1, false);
        vm.stopPrank();

        // revert case: buyer try to exercise again
        vm.startPrank(buyer);
        vm.expectRevert("Warrant not eligible for exercise");
        pair.exerciseWarrant(1, false);
        vm.stopPrank();
    }

    function test_exerciseCallCash() public {
        // price goes up
        test_buyCall();
        _forwardDays(7);
        _priceGoesUp();

        vm.startPrank(buyer);
        pair.exerciseWarrant(1, true);
        vm.stopPrank();

        // price goes down
        test_buyCall();
        _forwardDays(7);
        _priceGoesDown();

        // seller should get back baseAmount
        uint256 sellerBaseBalanceBefore = UNI.balanceOf(seller);
        vm.startPrank(buyer);
        pair.exerciseWarrant(2, true);
        vm.stopPrank();
        uint256 sellerBaseBalanceAfter = UNI.balanceOf(seller);
        assertEq(sellerBaseBalanceBefore + pair.getWarrant(2).baseAmount, sellerBaseBalanceAfter);
    }

    function test_cancelCall() public {
        // happy case
        // seller should get back baseAmount
        uint256 warrantId = _sellCall(5, 1, 12);
        uint256 sellerBaseBalanceBefore = UNI.balanceOf(seller);
        vm.startPrank(seller);
        pair.cancelWarrant(warrantId);
        vm.stopPrank();
        uint256 sellerBaseBalanceAfter = UNI.balanceOf(seller);
        assertEq(sellerBaseBalanceBefore + pair.getWarrant(warrantId).baseAmount, sellerBaseBalanceAfter);

        // revert case: already canceled
        vm.startPrank(seller);
        vm.expectRevert("Warrant not eligible for cancel");
        pair.cancelWarrant(warrantId);
        vm.stopPrank();
    }

    function test_expireCall() public {
        _sellCall(5, 1, 12);

        // revert case: not mature
        vm.startPrank(admin);
        vm.expectRevert("Warrant not eligible for expire");
        pair.expireWarrant(1);
        vm.stopPrank();

        // happy case
        _forwardDays(7);
        vm.startPrank(admin);
        pair.expireWarrant(1);
        vm.stopPrank();

        // revert case: already sold
        test_buyCall();
        vm.startPrank(admin);
        vm.expectRevert("Warrant not eligible for expire");
        pair.expireWarrant(2);
        vm.stopPrank();
    }

    function test_sellPut() public {
        // happy case
        _sellPut(7, 1, 8);

        // revert case
        IWarrant.WarrantType warrantType = IWarrant.WarrantType.PUT;
        uint256 strikePrice = 7 * 10 ** USDT.decimals();
        uint256 maturity = block.timestamp + 7 days;
        uint256 baseAmount = 100 * 10 ** UNI.decimals();
        uint256 premium = 8 * 10 ** USDT.decimals() / 10;
        uint256 quoteAmount = strikePrice * baseAmount / 10 ** UNI.decimals();

        vm.startPrank(seller);
        // allow settlement to spend quoteAmount
        USDT.approve(address(settlement), quoteAmount); 
        vm.expectRevert("Seller quote balance not enough");
        pair.sellWarrant(warrantType, strikePrice, maturity, baseAmount, premium);
        vm.stopPrank();
    }

    function test_buyPut() public {
        uint256 warrantId = _sellPut(7, 1, 8);

        // happy case
        vm.startPrank(buyer);
        // allow settlement to spend premium
        USDT.approve(address(settlement), pair.getWarrant(warrantId).premium);
        // allow settlement to spend baseAmount
        UNI.approve(address(settlement), pair.getWarrant(warrantId).baseAmount);
        pair.buyWarrant(warrantId);
        vm.stopPrank();

        // revert case: another buyer try to buy the same warrant
        vm.startPrank(buyer2);
        USDT.approve(address(settlement), pair.getWarrant(warrantId).premium);
        UNI.approve(address(settlement), pair.getWarrant(warrantId).baseAmount);
        vm.expectRevert("Warrant not available for selling");
        pair.buyWarrant(warrantId);
        vm.stopPrank();
    }

    function test_exercisePutActual() public {
        test_buyPut();

        // revert case: buyer try to exercise before maturity
        vm.startPrank(buyer);
        vm.expectRevert("Warrant not mature or expired");
        pair.exerciseWarrant(1, false);
        vm.stopPrank();

        // revert case: another buyer try to exercise
        _forwardDays(7);
        vm.startPrank(buyer2);
        vm.expectRevert("Sender not buyer");
        pair.exerciseWarrant(1, false);
        vm.stopPrank();

        // happy case
        // _forwardDays(7);
        vm.startPrank(buyer);
        pair.exerciseWarrant(1, false);
        vm.stopPrank();

        // revert case: buyer try to exercise again
        vm.startPrank(buyer);
        vm.expectRevert("Warrant not eligible for exercise");
        pair.exerciseWarrant(1, false);
        vm.stopPrank();
    }

    function test_exercisePutCash() public {
        // price goes up
        test_buyPut();
        _forwardDays(7);
        _priceGoesUp();

        // seller should get back quoteAmount
        uint256 sellerQuoteBalanceBefore = USDT.balanceOf(seller);
        vm.startPrank(buyer);
        pair.exerciseWarrant(1, true);
        vm.stopPrank();
        uint256 sellerQuoteBalanceAfter = USDT.balanceOf(seller);
        assertEq(sellerQuoteBalanceBefore + pair.getWarrant(1).quoteAmount, sellerQuoteBalanceAfter);

        // price goes down
        test_buyPut();
        _forwardDays(7);
        _priceGoesDown();

        vm.startPrank(buyer);
        pair.exerciseWarrant(2, true);
        vm.stopPrank();
    }

    function test_cancelPut() public {
        // happy case
        // seller should get back quoteAmount
        uint256 warrantId = _sellPut(7, 1, 8);
        uint256 sellerQuoteBalanceBefore = USDT.balanceOf(seller);
        vm.startPrank(seller);
        pair.cancelWarrant(warrantId);
        vm.stopPrank();
        uint256 sellerQuoteBalanceAfter = USDT.balanceOf(seller);
        assertEq(sellerQuoteBalanceBefore + pair.getWarrant(warrantId).quoteAmount, sellerQuoteBalanceAfter);

        // revert case: already canceled
        vm.startPrank(seller);
        vm.expectRevert("Warrant not eligible for cancel");
        pair.cancelWarrant(warrantId);
        vm.stopPrank();
    }

    function test_expirePut() public {
        _sellPut(7, 1, 8);

        // revert case: not mature
        vm.startPrank(admin);
        vm.expectRevert("Warrant not eligible for expire");
        pair.expireWarrant(1);
        vm.stopPrank();

        // happy case
        _forwardDays(7);
        vm.startPrank(admin);
        pair.expireWarrant(1);
        vm.stopPrank();

        // revert case: already sold
        test_buyPut();
        vm.startPrank(admin);
        vm.expectRevert("Warrant not eligible for expire");
        pair.expireWarrant(2);
        vm.stopPrank();
    }

    function _sellCall(uint256 _strikePrice, uint256 _baseAmount, uint256 _premium) public returns (uint256) {
        IWarrant.WarrantType warrantType = IWarrant.WarrantType.CALL;
        uint256 strikePrice = _strikePrice * 10 ** USDT.decimals();
        uint256 maturity = block.timestamp + 7 days;
        uint256 baseAmount = _baseAmount * 10 ** UNI.decimals();
        uint256 premium = _premium * 10 ** USDT.decimals() / 10;

        vm.startPrank(seller);
        // allow settlement to spend baseAmount
        UNI.approve(address(settlement), baseAmount); 
        pair.sellWarrant(warrantType, strikePrice, maturity, baseAmount, premium);
        vm.stopPrank();

        return pair.getLastWarrantId();
    }

    function _sellPut(uint256 _strikePrice, uint256 _baseAmount, uint256 _premium) public returns (uint256) {
        IWarrant.WarrantType warrantType = IWarrant.WarrantType.PUT;
        uint256 strikePrice = _strikePrice * 10 ** USDT.decimals();
        uint256 maturity = block.timestamp + 7 days;
        uint256 baseAmount = _baseAmount * 10 ** UNI.decimals();
        uint256 premium = _premium * 10 ** USDT.decimals() / 10;
        uint256 quoteAmount = strikePrice * baseAmount / 10 ** UNI.decimals();

        vm.startPrank(seller);
        // allow settlement to spend quoteAmount
        USDT.approve(address(settlement), quoteAmount); 
        pair.sellWarrant(warrantType, strikePrice, maturity, baseAmount, premium);
        vm.stopPrank();

        return pair.getLastWarrantId();
    }

    function _priceGoesUp() public {
        // set mock price feed to 8
        mockPriceFeed.setPrice(8 * 10 ** mockPriceFeed.decimals());
    }

    function _priceGoesDown() public {
        // set mock price feed to 4
        mockPriceFeed.setPrice(4 * 10 ** mockPriceFeed.decimals());
    }

    function _forwardDays(uint256 daysToForward) public {
        uint256 secondsToForward = daysToForward * 24 * 60 * 60;
        vm.warp(block.timestamp + secondsToForward);
    }

}
