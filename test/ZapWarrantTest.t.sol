// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Settlement} from "src/Settlement.sol";
import {WarrantPair} from "src/WarrantPair.sol";
import {IWarrant} from "interfaces/IWarrant.sol";
import {MockChainlinkAggregator} from "src/MockChainlinkAggregator.sol";

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

    // address public UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    // address public USDT = 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06;

    // create 2 fake tokens
    MyToken UNI = new MyToken("UNI", "UNI");
    MyToken USDT = new MyToken("USDT", "USDT");

    MockChainlinkAggregator public mockPriceFeed;
    Settlement public settlement;
    WarrantPair public pair;

    function setUp() public {
        admin = address(this);
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");

        mockPriceFeed = new MockChainlinkAggregator();
        settlement = new Settlement(address(UNI), address(USDT));
        pair = new WarrantPair(settlement, admin, address(UNI), address(USDT), mockPriceFeed);

        // deal seller some UNI and USDT
        deal(address(UNI), seller, 1000 * 10 ** UNI.decimals());
        deal(address(USDT), seller, 1000 * 10 ** USDT.decimals());

        // deal buyer some UNI and USDT
        deal(address(UNI), buyer, 1000 * 10 ** UNI.decimals());
        deal(address(USDT), buyer, 1000 * 10 ** USDT.decimals());
    }

    function test_sellCall() public {
        IWarrant.WarrantType warrantType = IWarrant.WarrantType.CALL;
        uint256 strikePrice = 5 * 10 ** USDT.decimals();
        uint256 maturity = block.timestamp + 7 days;
        uint256 baseAmount = 1 * 10 ** UNI.decimals();
        uint256 premium = 12 * 10 ** USDT.decimals() / 10;

        vm.startPrank(seller);
        // allow settlement to spend baseAmount
        UNI.approve(address(settlement), baseAmount); 
        pair.sellWarrant(warrantType, strikePrice, maturity, baseAmount, premium);
        vm.stopPrank();
    }

    function test_buyCall() public {
        test_sellCall();

        vm.startPrank(buyer);
        // allow settlement to spend premium and quoteAmount
        USDT.approve(address(settlement), pair.getWarrant(1).premium + pair.getWarrant(1).quoteAmount);
        // buy warrant id 1
        pair.buyWarrant(1);
        vm.stopPrank();
    }

    function test_exerciseCallActual() public {
        test_buyCall();
        _forwardDays(7);

        vm.startPrank(buyer);
        // exercise warrant id 1
        pair.exerciseWarrant(1, false);
        vm.stopPrank();
    }

    function test_exerciseCallCash() public {
        test_buyCall();
        _forwardDays(7);
        _priceGoesUp();

        vm.startPrank(buyer);
        // exercise warrant id 1
        pair.exerciseWarrant(1, true);
        vm.stopPrank();
    }

    function test_cancelCall() public {
        test_sellCall();

        vm.startPrank(seller);
        pair.cancelWarrant(1);
        vm.stopPrank();
    }

    function test_expireCall() public {
        test_sellCall();
        _forwardDays(7);

        vm.startPrank(admin);
        pair.expireWarrant(1);
        vm.stopPrank();
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
