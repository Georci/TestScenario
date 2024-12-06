/**
 * 参数识别的实现：演示不变量异常状态
 *  不变量：balance > MIN_BALANCE
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DeployToken, DeployPair, FireWallDeployer, AttackFirst, AttackSecond} from "../src/Utils.sol";
import {Script, console} from "forge-std/Script.sol";

contract InvariantContract {
    // 合约的状态变量
    uint256 public balance;
    uint256 public constant MIN_BALANCE = 100; // 不变量：最小余额
    address public router;

    constructor() {
        balance = 200;
    }

    // 增加余额
    function deposit(uint256 amount) external {
        balance += amount;
    }

    // 提取余额
    function withdraw(uint256 amount) external {
        require(balance >= amount, "Insufficient balance");
        balance -= amount;
    }

    function set_router(address _router) external virtual {
        router = _router;
    }
}

contract CreateEnv is Script {
    FireWallDeployer firewall;

    function setUp() public {
        firewall = FireWallDeployer(0x138750fe5Ec71a2Ce58C36baa48d1Eb32e40D17d);
    }

    function run() public {
        //startBroadcast后，后续的执行都会被广播
        vm.startBroadcast();
        InvariantContract ic = new InvariantContract();
        console.log("InvariantContract address", address(ic));
        address[] memory enables = new address[](1);
        enables[0] = address(firewall.param_detect());
        string[] memory params = new string[](1);
        params[0] = "uint256";
        firewall.setProject(address(ic), ic.withdraw.selector, params, enables);
    }
}

contract AttackScript is Script {
    FireWallDeployer firewall;
    InvariantContract ic;

    function setUp() public {
        firewall = FireWallDeployer(0x138750fe5Ec71a2Ce58C36baa48d1Eb32e40D17d);
    }

    function run() public {
        //startBroadcast后，后续的执行都会被广播
        vm.startBroadcast();
    }
}
