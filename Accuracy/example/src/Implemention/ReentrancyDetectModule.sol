// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FireWallRegistry} from "./Registry.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

contract ReentrancyDetectModule {
    // 区块 => sender => 项目地址 => 函数选择器 => 调用次数
    mapping(uint256 => mapping(address => mapping(address => mapping(bytes4 => uint256)))) private call_times;

    address public router;
    address public manager;
    address public registry;

    // =============================修饰符=============================
    modifier check() {
        require(
            msg.sender == router || msg.sender == registry || msg.sender == manager,
            "ReentrancyDetectModule: permission denied"
        );
        _;
    }

    // =============================事件=============================
    event Reenter(address indexed project_addr, address indexed attacker, bytes4 indexed function_selector);
    event SetReentrancyConfig(address indexed project_addr, bytes4 indexed function_selector, uint256 max_calls);
    event RemoveReentrancyConfig(address indexed project_addr, bytes4 indexed function_selector);

    // registry、router都是通过与其proxy交互
    constructor(address _routerProxy, address _registryProxy) {
        router = _routerProxy;
        registry = _registryProxy;
        manager = msg.sender;
    }

    function setInfo(bytes memory data) external check {
        (address project, bytes4 functionSelector) = abi.decode(data, (address, bytes4));
        require(project != address(0), "ReentrancyDetectModule: project address cannot be zero");
    }

    function removeInfo(bytes memory data) external check {
        (address project, bytes4 functionSelector) = abi.decode(data, (address, bytes4));
        require(project != address(0), "ReentrancyDetectModule: project address cannot be zero");

        emit RemoveReentrancyConfig(project, functionSelector);
    }

    function detect(address project, string[] memory args, bytes memory data) external returns (bool) {
        // 权限控制
        require(msg.sender == router, "ReentrancyDetectModule: detect only router can call");
        bytes4 functionSelector = bytes4(data);

        uint256 currentBlock = block.number;
        uint256 currentCalls = call_times[currentBlock][tx.origin][project][functionSelector];

        if (currentCalls >= 3) {
            emit Reenter(project, tx.origin, functionSelector);
            revert("ReentrancyDetectModule: reentrancy detected");
        } else {
            call_times[currentBlock][tx.origin][project][functionSelector] = currentCalls + 1;
        }

        return true;
    }
}
