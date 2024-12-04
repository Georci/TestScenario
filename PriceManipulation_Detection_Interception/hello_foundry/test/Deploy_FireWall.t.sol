pragma solidity ^0.8.19;

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

contract uintTest is Test {
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

    function setUp() public {
        vm.startPrank(deployer, deployer);
        console.log("deployer %s", deployer);
        // ============================= deploy registry and router =============================
        registry = new FireWallRegistry();
        bytes memory InitData_Registry = abi.encodeWithSignature(
            "initialize(address)",
            deployer
        );
        proxyForRegistry = new ProxyForRegistry(
            address(registry),
            deployer,
            InitData_Registry
        );
        router = new FireWallRouter();
        bytes memory InitData_Router = abi.encodeWithSignature(
            "initialize(address,address)",
            address(proxyForRegistry),
            deployer
        );
        proxyForRouter = new ProxyForRouter(
            address(router),
            deployer,
            InitData_Router
        );
        // ============================= deploy modules through proxy =============================
        // 部署param模块
        paramModule = new ParamCheckModule(
            address(proxyForRouter),
            address(proxyForRegistry)
        );
        deployAndInitializeModule(
            address(paramModule),
            deployer,
            "param detect",
            true
        );
        // (bool success, ) = address(proxyForRegistry).call(addModuledata1);
        // 部署黑名单模块
        authModule = new AuthModule(
            address(proxyForRouter),
            address(proxyForRegistry)
        );
        deployAndInitializeModule(
            address(authModule),
            deployer,
            "black detect",
            true
        );
        // 部署价格操纵防护模块:1.价格清洗合约 2.防护模块 3.oracle合约
        // 部署价格清洗合约
        priceCleaningContract = new PriceCleaningContract();
        bytes memory InitData_PirceCleanProxy = abi.encodeWithSignature(
            "initialize(address)",
            deployer
        );
        priceCleaningProxy = new ProxyForPriceCleaningContract(
            address(priceCleaningContract),
            deployer,
            InitData_PirceCleanProxy
        );
        console.log("priceCleaningProxy deploy completed!");
        // 部署价格防护模块
        priceModule = new PriceManipulationPrevention();
        bytes memory InitData_PirceModuleProxy = abi.encodeWithSignature(
            "initialize(address,address)",
            deployer,
            address(priceCleaningProxy)
        );
        priceModuleProxy = new ProxyForPriceManipulation(
            address(priceModule),
            deployer,
            InitData_PirceModuleProxy
        );

        deployAndInitializeModule(
            address(priceModuleProxy),
            deployer,
            "price detect",
            true
        );
        bytes memory InitData_setPriceModule = abi.encodeWithSignature(
            "setPriceModule(address)",
            address(priceModuleProxy)
        );
        priceCleaningProxy.CallOn(InitData_setPriceModule);
        // 部署oracle合约、设置oracle中链下价格、设置价格清洗合约使用信息
        createTokenAndSetPair(deployer);
        simpleLending = new SimpleLending(
            address(eth),
            address(usdc),
            pair,
            address(proxyForRouter)
        );
        deploy_oracle();
        setOracle(103, 2);
        console.log("compelete setOracle price");
        setDexinfoInPriceCleaning();
        console.log("compelete setDexinfoInPriceCleaning");

        //========================deploy and registry test contract=====================
        console.log("address(proxyForRouter) :", address(proxyForRouter));
        testContract = new PriceMani(address(proxyForRouter));
        console.log("testContract address :", address(testContract));
        // 注册信息
        string[] memory params = new string[](1);
        params[0] = "uint256";
        address[] memory enableModules2 = new address[](1);
        enableModules2[0] = address(priceModuleProxy);
        // 注册受保护项目
        register(
            address(testContract),
            deployer,
            testContract.test_price.selector,
            params,
            enableModules2
        );
        // 为受保护项目添加保护信息
        update_priceManipulation();
        vm.stopPrank();
    }

    // 稳定币，将价格设置为1
    function setOracle(uint256 _price, uint8 _decimals) public {
        oracleContract.transmit(int192(int256(_price)), _decimals);
    }

    function test_price_detect() public {
        bytes memory data = abi.encode(true);
        vm.prank(deployer);
        console.logBytes(data);
        bool nonattack = testContract.test_price(data);
        console.log("nonattack is :", nonattack);
    }

    // 正常情况能够置换的代币数量
    function test_simpleLoan() public {
        uint256 balance_pair_eth = eth.balanceOf(pair);
        uint256 balance_pair_usdc = usdc.balanceOf(pair);

        console.log("eth in pair:", balance_pair_eth);
        console.log("usdc in pair:", balance_pair_usdc);

        usdc._mint(address(simpleLending), 10000000);

        console.log(
            "eth in simpleLoan:",
            eth.balanceOf(address(simpleLending))
        );
        console.log(
            "usdc in simpleLoan:",
            usdc.balanceOf(address(simpleLending))
        );

        // 来一个user只有代币eth，使用一个代币A置换代币usdc
        address user = vm.addr(111);
        eth._mint(user, 2);
        console.log("before loan , user usdc:", usdc.balanceOf(user));
        vm.startPrank(user);
        eth.transfer(address(simpleLending), 1);
        simpleLending.requestLoan();
        console.log("after loan , user usdc:", usdc.balanceOf(user));
    }

    // 遭遇价格操纵攻击时，能够置换的代币数量
    function test_attack_simpleLoan() public {
        usdc._mint(address(simpleLending), 10000000);

        address attacker = vm.addr(112);
        // 攻击者通过闪电贷获取了大量的代币A
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();
        uint256 price_eth1 = IUniswapV2Pair(pair).token0() == address(eth)
            ? reserve1 / reserve0
            : reserve0 / reserve1;
        console.log("before attack, eth price in pair:", price_eth1);
        usdc._mint(attacker, 10000);
        eth._mint(attacker, 1);
        vm.startPrank(attacker);
        usdc.transfer(pair, 10000);
        IUniswapV2Pair(pair).sync();

        uint256 price_eth2 = IUniswapV2Pair(pair).token0() == address(eth)
            ? reserve1 / reserve0
            : reserve0 / reserve1;
        console.log("after attack, eth price in pair:", price_eth2);

        eth.transfer(address(simpleLending), 1);
        simpleLending.requestLoan();
        console.log("after loan , attacker usdc:", usdc.balanceOf(attacker));

        enable_firewall_monitor();
        identify_Malicious_Tx(10, true);
    }

    // 启动防火墙恶意交易识别
    function enable_firewall_monitor() public {
        string[] memory params = new string[](1);
        params[0] = "uint256";
        address[] memory enableModules2 = new address[](1);
        enableModules2[0] = address(priceModuleProxy);
        register(
            address(simpleLending),
            deployer,
            simpleLending.requestLoan.selector,
            params,
            enableModules2
        );
        console.log("enable firewall monitor");
    }

    function identify_Malicious_Tx(
        uint256 deviation,
        bool enableInterception
    ) public {
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();
        uint256 price_eth_targetPool = IUniswapV2Pair(pair).token0() ==
            address(eth)
            ? reserve1 / reserve0
            : reserve0 / reserve1;
        (uint112 reserve0_aave, uint112 reserve1_aave, ) = IUniswapV2Pair(
            aave_pair
        ).getReserves();
        uint256 price_eth_aavePool = IUniswapV2Pair(aave_pair).token0() ==
            address(eth)
            ? reserve1_aave / reserve0_aave
            : reserve0_aave / reserve1_aave;
        (uint112 reserve0_curve, uint112 reserve1_curve, ) = IUniswapV2Pair(
            curve_pair
        ).getReserves();
        uint256 price_eth_curvePool = IUniswapV2Pair(curve_pair).token0() ==
            address(eth)
            ? reserve1_curve / reserve0_curve
            : reserve0_curve / reserve1_curve;
        (
            uint112 reserve0_balancer,
            uint112 reserve1_balancer,

        ) = IUniswapV2Pair(balancer_pair).getReserves();
        uint256 price_eth_balancer = IUniswapV2Pair(balancer_pair).token0() ==
            address(eth)
            ? reserve1_balancer / reserve0_balancer
            : reserve0_balancer / reserve1_balancer;
        uint256 realPrice = (price_eth_balancer +
            price_eth_curvePool +
            price_eth_aavePool) / 3;

        uint256 priceDiff;
        console.log("realprice is :", realPrice);
        console.log("price_eth_targetPool is :", price_eth_targetPool);
        if (price_eth_targetPool > realPrice) {
            priceDiff = price_eth_targetPool - realPrice;
        } else {
            priceDiff = realPrice - price_eth_targetPool;
        }
        if (priceDiff > deviation) {
            console.log(
                "The settlement price is abnormal, a potential attack may be occurring"
            );
        }
        if (enableInterception) {
            interception_Malicious_Tx(
                realPrice,
                price_eth_targetPool,
                deviation
            );
        }
    }

    function interception_Malicious_Tx(
        uint256 realPrice,
        uint256 targetPrice,
        uint256 deviation
    ) public {
        uint256 priceDiff;
        if (targetPrice > realPrice) {
            priceDiff = targetPrice - realPrice;
        } else {
            priceDiff = realPrice - targetPrice;
        }
        if (priceDiff > deviation) {
            revert("Under attack, intercepted!");
        }
    }

    // 部署、初始化防火模块
    function deployAndInitializeModule(
        address moduleAddress,
        address manager,
        string memory description,
        bool enabled
    ) internal {
        bytes memory moduleData = abi.encodeWithSignature(
            "addModule(address,address,string,bool)",
            moduleAddress,
            manager,
            description,
            enabled
        );
        proxyForRegistry.CallOn(moduleData);
    }

    function register(
        address _targetContract,
        address _deployer,
        bytes4 _targetFunc,
        string[] memory _params,
        address[] memory _enableModules
    ) internal {
        bytes memory registryData = abi.encodeWithSignature(
            "register(address,address,bytes4,string[],address[])",
            _targetContract,
            _deployer,
            _targetFunc,
            _params,
            _enableModules
        );
        proxyForRegistry.CallOn(registryData);
    }

    function deploy_oracle() public {
        oracleContract = new OffchainAggregator(
            "ETH/USDC",
            address(eth),
            address(usdc),
            // 3%
            3,
            2,
            // 0.5%
            5,
            3
        );
        emit log_named_address(
            "oracle contract has been deployed at:",
            address(oracleContract)
        );
    }

    function setOracle_price() public {
        oracleContract.setDecimals(0);
        oracleContract.transmit(2400, 0);
    }

    // 初始化价格清洗合约 dex
    /**
     * @dev 在当前项目中，我们将Aave, Curve, Balancer中eth/usdc作为PriceCleaningContract中真实价格计算的数据来源
     */
    // Aave
    function setDexinfoInPriceCleaning() public {
        bytes memory call_data2 = abi.encodeWithSignature(
            "addDexInfo(address,address,address,address,uint8)",
            address(oracleContract),
            aave_pair,
            address(eth),
            address(usdc),
            10
        );
        priceCleaningProxy.CallOn(call_data2);

        // curve
        bytes memory call_data3 = abi.encodeWithSignature(
            "addDexInfo(address,address,address,address,uint8)",
            address(oracleContract),
            curve_pair,
            address(eth),
            address(usdc),
            10
        );
        priceCleaningProxy.CallOn(call_data3);

        // balancer
        bytes memory call_data4 = abi.encodeWithSignature(
            "addDexInfo(address,address,address,address,uint8)",
            address(oracleContract),
            balancer_pair,
            address(eth),
            address(usdc),
            10
        );
        priceCleaningProxy.CallOn(call_data4);
    }

    // 注册参数拦截模块
    function update_param() public {
        //参数拦截
        bytes memory data = abi.encode(
            address(testContract),
            testContract.test_param.selector,
            0,
            100,
            0,
            true
        );
        bytes memory paramUpdataData = abi.encodeWithSignature(
            "updataModuleInfo(address,bytes)",
            address(paramModule),
            data
        );
        proxyForRegistry.CallOn(paramUpdataData);
    }

    // 注册价格操纵模块
    /**
     * @dev 在整个测试中，假设当前testContract使用的是UniswapV2中的价格进行的金融结算
     */

    // TODO:现在遇到一个很关键的问题，我们无法决定一笔交易在进入到金融结算函数时，在哪个时刻启动价格操纵防护，目前的方案是只要这个函数被调用，就启动防护检查
    function update_priceManipulation() public {
        bytes memory data = abi.encode(
            address(testContract),
            testContract.test_price.selector,
            0,
            pair,
            address(eth),
            address(usdc),
            true,
            // 允许金融结算与真实价格的差值为 5%
            5,
            2,
            address(oracleContract)
        );
        bytes memory priceUpdataData = abi.encodeWithSignature(
            "updataModuleInfo(address,bytes)",
            address(priceModuleProxy),
            data
        );
        proxyForRegistry.CallOn(priceUpdataData);
    }

    /**
     * @dev 创建两个代币，并且创建几个pair
     */
    function createTokenAndSetPair(address price_manager) public {
        // 1.create token
        usdc = new ERC20("USDC", "usdc");
        eth = new ERC20("ETH", "eth");
        console.log("usdc address is :", address(usdc));
        console.log("eth address is :", address(eth));

        // 2.create pair
        uniswapV2_factory = new UniswapV2Factory(price_manager);
        pair = uniswapV2_factory.createPair(address(eth), address(usdc));
        console.log("uniswapV2 pair is :", pair);

        // 3.add liquidity
        usdc._mint(pair, 29900);
        eth._mint(pair, 100);

        IUniswapV2Pair(pair).sync();
        (uint256 amount1, uint256 amount2, ) = IUniswapV2Pair(pair)
            .getReserves();
        console.log("amount1 is :", amount1);
        console.log("amount2 is :", amount2);

        //4.ctrl C
        uniswapV2Aave_factory = new UniswapV2AaveFactory(price_manager);
        uniswapV2Curve_factory = new UniswapV2CurveFactory(price_manager);
        uniswapV2Balancer_factory = new UniswapV2BalancerFactory(price_manager);

        aave_pair = uniswapV2Aave_factory.createPair(
            address(eth),
            address(usdc)
        );
        curve_pair = uniswapV2Curve_factory.createPair(
            address(eth),
            address(usdc)
        );
        balancer_pair = uniswapV2Balancer_factory.createPair(
            address(eth),
            address(usdc)
        );
        console.log("aave_pair pair is :", aave_pair);
        console.log("curve_pair pair is :", curve_pair);
        console.log("balancer_pair pair is :", balancer_pair);
        usdc._mint(aave_pair, 29900);
        eth._mint(aave_pair, 100);
        IUniswapV2Pair(aave_pair).sync();

        usdc._mint(curve_pair, 29900);
        eth._mint(curve_pair, 100);
        IUniswapV2Pair(curve_pair).sync();

        usdc._mint(balancer_pair, 29900);
        eth._mint(balancer_pair, 100);
        IUniswapV2Pair(balancer_pair).sync();
    }

    //     function setup_environment(
    //         address testContract,
    //         bytes4 selector
    //     ) public returns (address) {
    //         deployer = msg.sender;
    //         vm.startPrank(deployer, deployer);
    //         console.log("deployer %s", deployer);

    //         // ============================= deploy registry and router =============================
    //         registry = new FireWallRegistry();
    //         bytes memory InitData_Registry = abi.encodeWithSignature(
    //             "initialize(address)",
    //             deployer
    //         );
    //         proxyForRegistry = new ProxyForRegistry(
    //             address(registry),
    //             deployer,
    //             InitData_Registry
    //         );
    //         router = new FireWallRouter();
    //         bytes memory InitData_Router = abi.encodeWithSignature(
    //             "initialize(address,address)",
    //             address(proxyForRegistry),
    //             deployer
    //         );
    //         proxyForRouter = new ProxyForRouter(
    //             address(router),
    //             deployer,
    //             InitData_Router
    //         );

    //         // ============================= deploy modules through proxy =============================
    //         // 部署param模块
    //         paramModule = new ParamCheckModule(
    //             address(proxyForRouter),
    //             address(proxyForRegistry)
    //         );
    //         deployAndInitializeModule(
    //             address(paramModule),
    //             deployer,
    //             "param detect",
    //             true
    //         );
    //         // (bool success, ) = address(proxyForRegistry).call(addModuledata1);
    //         // 部署黑名单模块
    //         authModule = new AuthModule(
    //             address(proxyForRouter),
    //             address(proxyForRegistry)
    //         );
    //         deployAndInitializeModule(
    //             address(authModule),
    //             deployer,
    //             "black detect",
    //             true
    //         );
    //         // 部署价格操纵防护模块:1.价格清洗合约 2.防护模块 3.oracle合约
    //         // 部署价格清洗合约
    //         priceCleaningContract = new PriceCleaningContract();
    //         bytes memory InitData_PirceCleanProxy = abi.encodeWithSignature(
    //             "initialize(address)",
    //             deployer
    //         );
    //         priceCleaningProxy = new ProxyForPriceCleaningContract(
    //             address(priceCleaningContract),
    //             deployer,
    //             InitData_PirceCleanProxy
    //         );
    //         console.log("priceCleaningProxy deploy completed!");

    //         // 部署价格防护模块
    //         priceModule = new PriceManipulationPrevention();
    //         bytes memory InitData_PirceModuleProxy = abi.encodeWithSignature(
    //             "initialize(address,address,int256)",
    //             deployer,
    //             address(priceCleaningProxy),
    //             10
    //         );
    //         priceModuleProxy = new ProxyForPriceManipulation(
    //             address(priceModule),
    //             deployer,
    //             InitData_PirceModuleProxy
    //         );
    //         deployAndInitializeModule(
    //             address(priceModuleProxy),
    //             deployer,
    //             "price detect",
    //             true
    //         );

    //         bytes memory InitData_setPriceModule = abi.encodeWithSignature(
    //             "setPriceModule(address)",
    //             address(priceModuleProxy)
    //         );

    //         priceCleaningProxy.CallOn(InitData_setPriceModule);

    //         // 部署oracle合约、设置oracle中链下价格、设置价格清洗合约使用信息
    //         createTokenAndSetPair();
    //         deploy_oracle();
    //         setOracle_price();
    //         setDexinfoInPriceCleaning();

    //         //========================deploy and registry test contract=====================
    //         console.log("testContract address :", address(testContract));
    //         // 注册信息
    //         string[] memory params = new string[](1);
    //         params[0] = "uint256";
    //         address[] memory enableModules2 = new address[](1);
    //         enableModules2[0] = address(priceModuleProxy);

    //         // 注册受保护项目
    //         register(
    //             address(testContract),
    //             deployer,
    //             selector,
    //             params,
    //             enableModules2
    //         );

    //         // 为受保护项目添加保护信息
    //         update_param();
    //         update_priceManipulation();

    //         return address(proxyForRouter);
    //     }
}
