pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DeployToken, DeployPair, FireWallDeployer, AttackFirst, AttackSecond} from "../src/Utils.sol";

contract CreateEnv is Script {
    FireWallDeployer firewall;
    // holesky network

    function setUp() public {
        firewall = FireWallDeployer(0x28B29067ee136542C509F24CF5d225667237D550);
        vm.label(0x9E31a838Ca49a45dfc0A934EeD64589e67f912cb, "ReentrancyDetector");
        vm.label(0x78593B45e54511dDaE746A6996D297474505b06D, "ProxyRouter");
        vm.label(0xf11aDE3dd57cCF39628e37dE9146020Ae8419291, "Router");
        vm.label(0x4eD7a7a906D767F9aEaA4F8d9B96332B43c62A4e, "registryProxy");
        vm.label(0x222E53F54ff73C5Af42c36c3CCa240F8627B8F68, "registry");
        vm.label(0xC6402FD79576052379640a29AdCf0D26040F2434, "ParamDetector");
    }

    function run() public {
        //startBroadcast后，后续的执行都会被广播
        vm.startBroadcast();
        DeployToken tokens = new DeployToken();
        DeployPair pairs = new DeployPair(tokens);
        tokens.setLiquidity(pairs.factory());

        console.log("Firewall Address %s", address(firewall));
        address[] memory enables = new address[](1);
        enables[0] = address(firewall.param_detect());
        string[] memory params = new string[](1);
        params[0] = "uint256";
        firewall.setProject(address(tokens.bevo()), tokens.bevo().deliver.selector, params, enables);
        console.log("BEVO Address %s", address(tokens.bevo()));
        vm.label(address(tokens.bevo()), "BEVO");
        vm.label(address(tokens.usdc()), "USDC");
        vm.label(address(tokens.wbnb()), "WBNB");
        vm.label(address(pairs.usdc_wbnb()), "USDC_WBNB");
        vm.label(address(pairs.wbnb_bevo()), "WBNB_BEVO");
        vm.label(address(pairs.factory()), "Factory");
        AttackFirst attacker1 = new AttackFirst(pairs.factory(), tokens);
        console.log("first attacker address %s", address(attacker1));
        AttackSecond attacker2 = new AttackSecond(pairs.factory(), tokens);
        console.log("second attacker address %s", address(attacker2));
        console.log("param_detect Address %s", address(firewall.param_detect()));
        console.log("proxy_registry Address %s", address(firewall.proxy_registry()));
        vm.stopBroadcast();
    }
}
