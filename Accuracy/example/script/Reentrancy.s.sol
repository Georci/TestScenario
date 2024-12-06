pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DeployToken, DeployPair, FireWallDeployer, AttackFirst, AttackSecond} from "../src/Utils.sol";
import {EtherStore, Attack, Normal} from "../src/vulns/DAO.sol";
import {Accuracy_example} from "./example.sol";

contract CreateEnv is Script {
    // holesky network
    FireWallDeployer firewall;

    function run() public {
        //startBroadcast后，后续的执行都会被广播
        vm.startBroadcast();

        firewall = new FireWallDeployer();
        EtherStore ethstore = new EtherStore{value: 0.0003 ether}();
        Attack attacker = new Attack(address(ethstore));
        Normal sender = new Normal(address(ethstore));

        address[] memory enables = new address[](2);
        enables[0] = address(firewall.reen_detect());
        enables[1] = address(firewall.auth_detect());
        string[] memory params = new string[](1);

        firewall.setProject(
            address(ethstore),
            ethstore.withdraw.selector,
            params,
            enables
        );
        
        vm.stopBroadcast(); // 停止广播
    }


    // 部署Attack合约与Normal合约
    // function run() public {
    //     vm.startBroadcast();

    //     address ethstore = 0xcbfc7de5b85C135fCC03E313c8e4E6AA2729450C;
    //     Attack attacker = new Attack(ethstore);
    //     Normal sender = new Normal(ethstore);
    //     vm.stopBroadcast(); // 停止广播
    // }


    // 部署受保护项目ethstore
    // function run() public {
    //     vm.startBroadcast();

    //     EtherStore ethstore = new EtherStore{value: 0.0003 ether}();
    //     vm.stopBroadcast(); // 停止广播
    // }

}
