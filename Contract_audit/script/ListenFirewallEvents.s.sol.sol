// pragma solidity ^0.8.19;

// import {Script} from "../lib/forge-std/src/Script.sol";
// import {Test, console} from "../lib/forge-std/src/Test.sol";
// import {FireWallDeployer} from "../src/Utils.sol";

// contract test_contract_audit is Script {
//     address firewall = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;

//     function run() external {
//         // 初始化智能合约防火墙
//         console.log("Listening to Firewall events...");
//         // 监听 ProjectAddedToProtection 事件
//         vm.onEvent(
//             firewall,
//             abi.encodeWithSignature("ProjectAddedToProtection(address)"),
//             this.handleEvent
//         );
//     }

//     function handleEvent(bytes calldata data) external {
//         address project = abi.decode(data, (address));
//         console.log("Project added to protection:", project);
//     }
// }
