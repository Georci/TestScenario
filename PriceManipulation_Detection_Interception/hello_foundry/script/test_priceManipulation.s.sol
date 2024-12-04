pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test, console} from "../lib/forge-std/src/Test.sol";
import {FireWallRouter} from "../src/Implemention/Router.sol";
import {FireWallRegistry} from "../src/Implemention/Registry.sol";
import {IModule} from "../src/Implemention/Interface/IModule.sol";
import {AuthModule} from "../src/Implemention/AuthenticationModule.sol";
import {PriceMani} from "../src/example/test_PriceMani_contract.sol";
import {ParamCheckModule} from "../src/Implemention/ParamCheckModule.sol";

//============================== proxy =============================
import {ProxyForRegistry} from "../src/proxy/proxyForRegistry.sol";
import {FireWallRegistryV2} from "../src/Implemention/RegistryV2.sol";
import {ProxyForRouter} from "../src/proxy/proxyForRouter.sol";
import {FireWallRouterV2} from "../src/Implemention/RouterV2.sol";
import {SimpleSwap} from "../src/example/testFireWallexp.sol";

import "../src/proxy/utils/StorageSlot.sol";
import "../src/proxy/utils/Address.sol";

//============================== price mainpulation =============================
import {PriceManipulationPrevention} from "../src/Implemention/PriceManipulationModule/PriceManipulationPreventionModule.sol";
import {ProxyForPriceManipulation} from "../src/Implemention/PriceManipulationModule/ProxyForPriceManipulation.sol";
import {ProxyForPriceCleaningContract} from "../src/Implemention/OnchainOracle/ProxyPriceCleaningContract.sol";
import {PriceCleaningContract} from "../src/Implemention/OnchainOracle/PriceCleaningContract.sol";
import {OffchainAggregator} from "../src/Implemention/OnchainOracle/OracleContract.sol";

//============================== token =============================
import {ERC20} from "../src/Implemention/OnchainOracle/token.sol";
import {UniswapV2Factory} from "../uniswapv2-solc0.8/contracts/UniswapV2Factory.sol";
import {UniswapV2BalancerFactory} from "../uniswapv2-solc0.8/contracts/UniswapV2(Balancer)Factory.sol";
import {UniswapV2CurveFactory} from "../uniswapv2-solc0.8/contracts/UniswapV2(Curve)Factory.sol";
import {UniswapV2AaveFactory} from "../uniswapv2-solc0.8/contracts/UniswapV2(Aave)Factory.sol";
import {IUniswapV2Pair} from "../uniswapv2-solc0.8/contracts/interfaces/IUniswapV2Pair.sol";

import {SimpleLending} from "../src/project/project1.sol";

contract MyTestScript is Script {
    address deployer = vm.addr(1);
    address auth_manager = vm.addr(2);
    address param_manager = vm.addr(3);
    address projectManager = vm.addr(4);
    address admin = vm.addr(6);

    FireWallRegistry registry;
    ProxyForRegistry proxyForRegistry;
    FireWallRouter router;
    ProxyForRouter proxyForRouter;
    AuthModule authModule;

    ParamCheckModule paramModule;
    // ======================== 与价格操纵相关的测试 ========================
    PriceManipulationPrevention priceModule;
    ProxyForPriceManipulation priceModuleProxy;
    PriceMani testContract;
    PriceCleaningContract priceCleaningContract;
    ProxyForPriceCleaningContract priceCleaningProxy;
    OffchainAggregator oracleContract;

    ERC20 usdc;
    ERC20 eth;
    UniswapV2Factory uniswapV2_factory;
    UniswapV2AaveFactory uniswapV2Aave_factory;
    UniswapV2CurveFactory uniswapV2Curve_factory;
    UniswapV2BalancerFactory uniswapV2Balancer_factory;
    address pair;
    address aave_pair;
    address curve_pair;
    address balancer_pair;

    SimpleLending simpleLending;

    function run() external {
        
    }
}
