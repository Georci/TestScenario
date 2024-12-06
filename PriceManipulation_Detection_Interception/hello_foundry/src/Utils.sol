pragma solidity ^0.8.20;

import {Test, console} from "../lib/forge-std/src/Test.sol";
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
import {OffchainAggregator} from "../src/Implemention/OnchainOracle/OracleContract.sol";

//============================== token =============================
import {ERC20} from "../src/Implemention/OnchainOracle/token.sol";
import {UniswapV2Factory} from "../uniswapv2-solc0.8/contracts/UniswapV2Factory.sol";
import {UniswapV2BalancerFactory} from "../uniswapv2-solc0.8/contracts/UniswapV2(Balancer)Factory.sol";
import {UniswapV2CurveFactory} from "../uniswapv2-solc0.8/contracts/UniswapV2(Curve)Factory.sol";
import {UniswapV2AaveFactory} from "../uniswapv2-solc0.8/contracts/UniswapV2(Aave)Factory.sol";
import {IUniswapV2Pair} from "../uniswapv2-solc0.8/contracts/interfaces/IUniswapV2Pair.sol";

import {SimpleLending} from "../src/project/project1.sol";

contract FireWallDeployer {
    // registry router
    FireWallRegistry public registry;
    ProxyForRegistry public proxy_registry;
    FireWallRouter public router;
    ProxyForRouter public proxy_router;

    // price module
    PriceCleaningContract public priceCleaningContract;
    ProxyForPriceCleaningContract public priceCleaningProxy;
    PriceManipulationPrevention public priceModule;
    ProxyForPriceManipulation public priceModuleProxy;
    OffchainAggregator public oracleContract;

    // token
    ERC20 public usdc;
    ERC20 public eth;
    UniswapV2Factory public uniswapV2_factory;
    UniswapV2AaveFactory public uniswapV2Aave_factory;
    UniswapV2CurveFactory public uniswapV2Curve_factory;
    UniswapV2BalancerFactory public uniswapV2Balancer_factory;
    address public pair;
    address public aave_pair;
    address public curve_pair;
    address public balancer_pair;

    // 受保护的项目
    SimpleLending public simpleLending;

    constructor() {
        // 部署 router/registry
        address deployer = msg.sender;
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

    function set_environment() public {
        address deployer = msg.sender;
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

        bytes memory moduleData = abi.encodeWithSignature(
            "addModule(address,address,string,bool)",
            address(priceModuleProxy),
            deployer,
            "price detect",
            true
        );
        proxy_registry.CallOn(moduleData);
        bytes memory InitData_setPriceModule = abi.encodeWithSignature(
            "setPriceModule(address)",
            address(priceModuleProxy)
        );
        priceCleaningProxy.CallOn(InitData_setPriceModule);
        deployAndInitialize_oracle();
    }

    // 启动防火墙恶意交易识别
    function enable_firewall_monitor(
        uint256 a,
        bool enableInterception
    ) public {
        address deployer = msg.sender;
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
        // 在防火墙中设置项目信息
        update_priceManipulation(a, enableInterception);
        // identify_Malicious_Tx(10, false);
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
        // if (enableInterception) {
        //     interception_Malicious_Tx(
        //         realPrice,
        //         price_eth_targetPool,
        //         deviation
        //     );
        // }
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

    function deployAndInitialize_oracle() public {
        address deployer = msg.sender;
        createTokenAndSetPair(deployer);
        simpleLending = new SimpleLending(
            address(eth),
            address(usdc),
            pair,
            address(proxy_router)
        );
        deploy_oracle_contract();
        setOracle(299, 0);
        console.log("compelete setOracle price");
        setDexinfoInPriceCleaning();
        console.log("compelete setDexinfoInPriceCleaning");
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
        proxy_registry.CallOn(registryData);
    }

    function deploy_oracle_contract() public {
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
        console.log(
            "oracle contract has been deployed at:",
            address(oracleContract)
        );
    }

    function setOracle(uint256 _price, uint8 _decimals) public {
        oracleContract.transmit(int192(int256(_price)), _decimals);
    }

    function setOracle_price() public {
        oracleContract.setDecimals(0);
        oracleContract.transmit(2400, 0);
    }

    function update_priceManipulation(
        uint256 deviation,
        bool enableInterception
    ) public {
        bytes memory data = abi.encode(
            enableInterception,
            address(simpleLending),
            simpleLending.requestLoan.selector,
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
        proxy_registry.CallOn(priceUpdataData);
    }

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
}
