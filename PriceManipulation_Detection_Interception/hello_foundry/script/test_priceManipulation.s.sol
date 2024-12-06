pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test, console} from "../lib/forge-std/src/Test.sol";
import {FireWallDeployer} from "../src/Utils.sol";
import {IUniswapV2Pair} from "../uniswapv2-solc0.8/contracts/interfaces/IUniswapV2Pair.sol";

contract MyTestScript is Script {
    FireWallDeployer firewall;

    function setUp() public {
        // 初始化智能合约防火墙
        firewall = new FireWallDeployer();
    }

    function run() external {
        // 启动智能合约防火墙价格操纵防护系统
        firewall.set_environment();

        // 启动危险价格检测
        firewall.enable_firewall_monitor(5, true);

        // test_attack_simpleLoan();
        // test_simpleLoan();
    }

    // 正常情况能够置换的代币数量
    function test_simpleLoan() public {
        address pair = firewall.pair();
        uint256 balance_pair_eth = firewall.eth().balanceOf(pair);
        uint256 balance_pair_usdc = firewall.usdc().balanceOf(pair);

        console.log("eth in pair:", balance_pair_eth);
        console.log("usdc in pair:", balance_pair_usdc);

        firewall.usdc()._mint(address(firewall.simpleLending()), 10000000);

        console.log(
            "eth in simpleLoan:",
            firewall.eth().balanceOf(address(firewall.simpleLending()))
        );
        console.log(
            "usdc in simpleLoan:",
            firewall.usdc().balanceOf(address(firewall.simpleLending()))
        );

        // 来一个user只有代币eth，使用一个代币A置换代币usdc
        address user = vm.addr(111);
        firewall.eth()._mint(user, 2);
        uint256 beforeLoan_amount = firewall.usdc().balanceOf(user);
        console.log("before loan , user usdc:", beforeLoan_amount);
        vm.startPrank(user);
        firewall.eth().transfer(address(firewall.simpleLending()), 1);
        firewall.simpleLending().requestLoan();
        uint256 afterLoan_amount = firewall.usdc().balanceOf(user);
        console.log("after loan , user usdc:", afterLoan_amount);

        uint256 normalLoan_amount = afterLoan_amount - beforeLoan_amount;
        console.log("normalLoan_amount: ", normalLoan_amount);
    }

    // 遭遇价格操纵攻击时，能够置换的代币数量
    function test_attack_simpleLoan() public {
        address pair = firewall.pair();
        firewall.usdc()._mint(address(firewall.simpleLending()), 10000000);

        address attacker = vm.addr(112);
        // 攻击者通过闪电贷获取了大量的代币A
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();
        uint256 price_eth1 = IUniswapV2Pair(pair).token0() ==
            address(firewall.eth())
            ? reserve1 / reserve0
            : reserve0 / reserve1;
        console.log("before attack, eth price in pair:", price_eth1);
        firewall.usdc()._mint(attacker, 10000);
        firewall.eth()._mint(attacker, 1);
        vm.startPrank(attacker);
        firewall.usdc().transfer(pair, 10000);
        IUniswapV2Pair(pair).sync();

        uint256 price_eth2 = IUniswapV2Pair(pair).token0() ==
            address(firewall.eth())
            ? reserve1 / reserve0
            : reserve0 / reserve1;
        console.log("after attack, eth price in pair:", price_eth2);

        firewall.eth().transfer(address(firewall.simpleLending()), 1);
        uint256 beforeLoan_amount = firewall.usdc().balanceOf(attacker);
        console.log("before loan , attacker usdc:", beforeLoan_amount);
        firewall.simpleLending().requestLoan();
        uint256 afterLoan_amount = firewall.usdc().balanceOf(attacker);
        console.log("after loan , attacker usdc:", afterLoan_amount);
        uint256 attackLoan_amount = afterLoan_amount - beforeLoan_amount;

        console.log("attackLoan_amount: ", attackLoan_amount);
    }
}
