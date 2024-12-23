pragma solidity ^0.8.0;

import {simpleProject} from "../src/project/simpleProject.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {console} from "../lib/forge-std/src/Test.sol";

contract ProtectedProject is Script {
    function run() external {
        vm.startBroadcast();

        simpleProject simple_project = new simpleProject();
        console.log("simple_project deployed at :", address(simple_project));

        vm.stopBroadcast();
    }
}
