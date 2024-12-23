pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";
import {FireWallRouter} from "../src/Implemention/Router.sol";
import {FireWallRegistry} from "../src/Implemention/Registry.sol";
import {IModule} from "../src/Implemention/Interface/IModule.sol";
import {AuthModule} from "../src/Implemention/AuthenticationModule.sol";
import {PriceMani} from "../src/example/test_PriceMani_contract.sol";
import {ParamCheckModule} from "../src/Implemention/ParamCheckModule.sol";

//============================== proxy =============================
import {ProxyForRegistry} from "../src/proxy/proxyForRegistry.sol";
import {ProxyForRouter} from "../src/proxy/proxyForRouter.sol";

import "../src/proxy/utils/StorageSlot.sol";
import "../src/proxy/utils/Address.sol";

//============================== price mainpulation =============================
import {PriceManipulationPrevention} from "../src/Implemention/PriceManipulationModule/PriceManipulationPreventionModule.sol";
import {ProxyForPriceManipulation} from "../src/Implemention/PriceManipulationModule/ProxyForPriceManipulation.sol";
import {ProxyForPriceCleaningContract} from "../src/Implemention/OnchainOracle/ProxyPriceCleaningContract.sol";
import {PriceCleaningContract} from "../src/Implemention/OnchainOracle/PriceCleaningContract.sol";

import {SimpleLending} from "../src/project/project1.sol";

contract FireWallDeployer {
    uint256 public a = 0;
    // registry router
    FireWallRegistry public registry;
    ProxyForRegistry public proxy_registry;
    FireWallRouter public router;
    ProxyForRouter public proxy_router;

    // 受保护的项目
    SimpleLending public simpleLending;

    event registerEvent(address indexed registeredProject);
    event AuditLog(address indexed project, string message, uint256 timestamp);

    constructor(address deployer) {
        // 部署 router/registry
        registry = new FireWallRegistry();
        bytes memory InitData_Registry = abi.encodeWithSignature(
            "initialize(address)",
            deployer
        );
        proxy_registry = new ProxyForRegistry(
            address(registry),
            deployer,
            InitData_Registry
        );
        router = new FireWallRouter();
        bytes memory InitData_Router = abi.encodeWithSignature(
            "initialize(address,address)",
            address(proxy_registry),
            deployer
        );
        proxy_router = new ProxyForRouter(
            address(router),
            deployer,
            InitData_Router
        );
    }

    // 也就是说当firewallDepolyer.proxy_registry的函数CallOn被调用时，就意味着有新的函数加入到防火墙的保护中
    function register(
        address _targetContract,
        address _deployer,
        bytes4 _targetFunc,
        string[] memory _params,
        address[] memory _enableModules
    ) public {
        bytes memory registryData = abi.encodeWithSignature(
            "register(address,address,bytes4,string[],address[])",
            _targetContract,
            _deployer,
            _targetFunc,
            _params,
            _enableModules
        );
        proxy_registry.CallOn(registryData);
        a += 1;
        emit registerEvent(_targetContract);
    }

    function audit(address targetProject) public {
        console.log("start audit!");
        // 模拟审计开始
        emit AuditLog(targetProject, "Audit started", block.timestamp);
        analysis(targetProject, true);
        a += 1;
        // 模拟一些审计步骤
        emit AuditLog(
            targetProject,
            "Step 1: Checking permissions",
            block.timestamp
        );
        emit AuditLog(
            targetProject,
            "Step 2: Analyzing contract bytecode",
            block.timestamp
        );
        emit AuditLog(
            targetProject,
            "Step 3: Running symbolic execution",
            block.timestamp
        );

        // 模拟审计完成
        emit AuditLog(
            targetProject,
            "Audit completed successfully",
            block.timestamp
        );
    }

    function analysis(address project, bool a) public {
        if (a) {
            console.log("project has some errors");
        } else {
            console.log("project has no errors");
        }
    }
}
