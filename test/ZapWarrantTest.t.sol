// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Settlement} from "src/Settlement.sol";
import {WarrantPair} from "src/WarrantPair.sol";
import {IWarrant} from "interfaces/IWarrant.sol";

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

    Settlement public settlement;
    WarrantPair public pair;

    function setUp() public {
        admin = address(this);
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");

        settlement = new Settlement(address(UNI), address(USDT));
        pair = new WarrantPair(settlement, admin, address(UNI), address(USDT));

        // deal seller some UNI and USDT
        deal(address(UNI), seller, 1000 * 10 ** UNI.decimals());
        deal(address(USDT), seller, 1000 * 10 ** USDT.decimals());

        // deal buyer some UNI and USDT
        deal(address(UNI), buyer, 1000 * 10 ** UNI.decimals());
        deal(address(USDT), buyer, 1000 * 10 ** USDT.decimals());
    }

    function test_sellCall() public {
        vm.startPrank(seller);

        // allow settlement to spend 10 UNI
        UNI.approve(address(settlement), 10 * 10 ** UNI.decimals());

        // warrant type is call
        // strike price is 7
        // maturity is 3 days later
        // base amount is 10 UNI
        // premium is 1 USDT
        pair.sellWarrant(
            IWarrant.WarrantType.CALL,
            7 * 10 ** UNI.decimals(),
            block.timestamp + 3 days,
            10 * 10 ** UNI.decimals(),
            1 * 10 ** USDT.decimals()
        );

        vm.stopPrank();

        // warrant map
        Warrant[] memory warrants = pair.getWarrants();
        // print warrants

    }

    function test_buyCall() public {
        test_sellCall();

        vm.startPrank(buyer);

        // allow settlement to spend 100 USDT
        USDT.approve(address(settlement), 100 * 10 ** USDT.decimals());

        // buy warrant id 1
        pair.buyWarrant(1);

        vm.stopPrank();

        Warrant memory warrant = pair.getWarrant(1);
    }

    function test_exerciseCall() public {
        test_buyCall();

        // forward time 3 days
        uint256 threeDaysInSeconds = 3 * 24 * 60 * 60;
        vm.warp(block.timestamp + threeDaysInSeconds);

        vm.startPrank(buyer);

        // exercise warrant id 1
        pair.exerciseWarrant(1);

        vm.stopPrank();

        Warrant memory warrant = pair.getWarrant(1);
    }

    function test_cancelCall() public {
        test_sellCall();

        vm.startPrank(seller);
        pair.cancelWarrant(1);
        vm.stopPrank();

        Warrant memory warrant = pair.getWarrant(1);
    }

    function test_expireCall() public {
        test_sellCall();

        // forward time 3 days
        uint256 threeDaysInSeconds = 3 * 24 * 60 * 60;
        vm.warp(block.timestamp + threeDaysInSeconds);

        vm.startPrank(admin);
        pair.expireWarrant(1);
        vm.stopPrank();

        Warrant memory warrant = pair.getWarrant(1);
    }

}
