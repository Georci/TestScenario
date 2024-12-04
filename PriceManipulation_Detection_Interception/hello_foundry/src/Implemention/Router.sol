//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModule} from "./Interface/IModule.sol";
import {FireWallRegistry} from "./Registry.sol";
import {ProxyForRegistry} from "../proxy/proxyForRegistry.sol";
import "../../lib/forge-std/src/Test.sol";

// import {Test, console} from "forge-std/Test.sol";

contract FireWallRouter {
    // 注册表地址
    // FireWallRegistry public registry;
    ProxyForRegistry registry_Proxy;

    // 管理者
    address public owner;

    // =============================修饰符=============================
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner can call");
        _;
    }

    // =============================事件==============================
    event AddProject(address project);
    event registryAddress(address registryAddr);
    event pauseProjectInteract(address project);
    event unpauseProjectInteract(address project);
    event pauseModuleForProject(address project, uint64 module_index);

    // =============================检测函数=============================
    ///@notice ProtectInfosize is the function getProtectInfo's returndata size.
    ///@notice info is the function getProtectInfo's returndata info.
    ///@notice is_ProjectPaused 表示从registry中查找项目是否暂停.
    function executeWithDetect(bytes memory data) external returns (bool) {
        // 通过代理获取查询信息
        bytes memory Proxy_data = abi.encodeWithSignature(
            "getProtectInfo(address,bytes4)",
            msg.sender,
            bytes4(data)
        );
        registry_Proxy.CallOn(Proxy_data);
        bytes memory ProtectInfo;
        assembly {
            let ProtectInfosize := returndatasize()
            ProtectInfo := mload(0x40)
            mstore(ProtectInfo, ProtectInfosize)
            returndatacopy(add(ProtectInfo, 0x20), 0, ProtectInfosize)
            mstore(0x40, add(add(ProtectInfo, 0x20), ProtectInfosize))
        }
        // console.logBytes(ProtectInfo);
        FireWallRegistry.ProtectInfo memory info = abi.decode(
            ProtectInfo,
            (FireWallRegistry.ProtectInfo)
        );

        // 判断是否暂停(项目暂停，函数暂停):为了区别V1、V2, 下面这段代码在V2中被使用

        require(!info.is_pause, "project function is pause interaction");
        // 遍历
        for (uint256 index = 0; index < info.enableModules.length; index++) {
            address detectMod = info.enableModules[index];
            // 拆开参数
            string[] memory args = info.params;
            IModule(detectMod).detect(msg.sender, args, data);
        }
        return true;
    }

    ///@notice Initialize router's data.
    ///@param _owner The address of owner.
    function initialize(
        address payable _registry_Proxy,
        address _owner
    ) external {
        registry_Proxy = ProxyForRegistry(_registry_Proxy);
        owner = _owner;
    }
}
