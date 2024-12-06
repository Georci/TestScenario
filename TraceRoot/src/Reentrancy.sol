// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ReentrancyVulnerable {
    mapping(address => uint256) public balances;

    // 存款功能
    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    // 提款功能（存在重入漏洞）
    function withdraw(uint256 _amount) public {
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        // 更新余额之前，先进行外部转账，导致攻击者可以重入合约
        payable(msg.sender).transfer(_amount);

        // 重新进入合约后，进行余额更新
        balances[msg.sender] -= _amount;
    }
}
