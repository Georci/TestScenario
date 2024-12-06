pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DeployToken, DeployPair, FireWallDeployer, AttackFirst, AttackSecond} from "../src/Utils.sol";
import {EtherStore, Attack, Normal_tx} from "../src/vulns/DAO.sol";
import {Accuracy_example} from "./example.sol";

contract CreateEnv is Script {
    // holesky network
    FireWallDeployer firewall;
    address[] public blackList;

    function setUp() public {
        firewall = new FireWallDeployer();
    }

    function run() public {
        //startBroadcast后，后续的执行都会被广播
        vm.startBroadcast();

        firewall = new FireWallDeployer();
        initializeBlackList();
        EtherStore ethstore = new EtherStore{value: 0.0003 ether}();
        // address[] memory enables = new address[](1);
        // enables[0] = address(firewall.reen_detect());

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
        address[] memory blackList = blackList;
        firewall.batch_setblack(address(ethstore), blackList);
        // Attack attacker = new Attack(address(ethstore));
        // attacker.attack{value: 0.0001 ether}();

        // 模拟所有黑名单地址调用 sendTx
        // simulateBlackListTransactions(ethstore);
        vm.stopBroadcast(); // 停止广播
    }

    // 黑名单初始化函数
    function initializeBlackList() internal {
        for (uint256 i = 0; i < 50; i++) {
            address blackListed = address(
                uint160(uint256(keccak256(abi.encodePacked(i))))
            );
            console.log("blackListed is :", i, blackListed);
            blackList.push(blackListed);
        }
    }

    // 部署Attack合约与Normal_tx合约
    // function run() public {
    //     vm.startBroadcast();

    //     address ethstore = 0xcbfc7de5b85C135fCC03E313c8e4E6AA2729450C;
    //     Attack attacker = new Attack(ethstore);
    //     Normal_tx sender = new Normal_tx(ethstore);
    //     vm.stopBroadcast(); // 停止广播
    // }

    // 模拟所有黑名单地址的交易
    // function simulateBlackListTransactions(EtherStore ethstore) internal {
    //     for (uint256 i = 0; i < blackList.length; i++) {
    //         address blackListedUser = blackList[i];
    //         vm.deal(blackListedUser, 1 ether);

    //         vm.startPrank(blackListedUser, blackListedUser);
    //         try new Normal_tx(address(ethstore)).sendTx{value: 0.0001 ether}() {
    //             console.log(
    //                 "Blacklisted user transaction succeeded, unexpected!"
    //             );
    //         } catch {
    //             console.log(
    //                 "Transaction blocked for blacklisted user:",
    //                 blackListedUser
    //             );
    //         }
    //         vm.stopPrank();
    //     }
    // }
}
