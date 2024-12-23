pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {console} from "../lib/forge-std/src/Test.sol";
import {FireWallDeployer} from "../src/Utils.sol";

contract test_contract_audit is Script {
    // 1.部署智能合约防火墙
    // 2.打开监控
    // 3.添加项目到防火墙中
    // 4.出现审计信息
    FireWallDeployer firewall;

    function run() external {
        vm.startBroadcast();
        // 初始化智能合约防火墙
        address dployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        firewall = new FireWallDeployer(dployer);
        console.log("Firewall deployed at:", address(firewall));

        vm.stopBroadcast();
    }

}
