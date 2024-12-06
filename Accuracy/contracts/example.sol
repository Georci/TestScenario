// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract Accuracy_example {
    // 模拟用户余额的映射
    uint256 public totalSupply;
    mapping(address => uint256) public balances;

    constructor(uint256 _totalSupply) {
        totalSupply = _totalSupply;
    }

    // 用户存款逻辑，用于初始化余额
    function deposit(uint256 amount) public {
        balances[msg.sender] += amount;
    }

    // 重入逻辑：无限循环调用自己，模拟重入问题
    function reentrancyLogic(uint256 loopCount) private {
        for (uint256 i = 0; i < loopCount; i++) {
            balances[msg.sender]++; // 模拟消耗余额
            totalSupply--;
        }
    }

    // 正常逻辑：只减少特定的余额
    function normalLogic(uint256 amount) private {
        balances[msg.sender] += amount; // 减少用户余额
        totalSupply -= amount;
    }

    function processTransaction(uint256 parameter, uint256 amount) public {
        if (parameter >= 1 && parameter <= 10) {
            reentrancyLogic(amount); // 执行重入逻辑
        } else {
            normalLogic(amount); // 执行正常逻辑
        }
    }
}
