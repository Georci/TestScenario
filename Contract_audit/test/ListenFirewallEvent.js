const { ethers } = require("hardhat")
const { audit } = require("./Test")

require("dotenv").config();

const RPC_URL = process.env.ANVIL_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

// 合约地址和 ABI
const firewallAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const firewallAbi = require("../out/Utils.sol/FireWallDeployer.json").abi;
const provider = new ethers.JsonRpcProvider(RPC_URL);
const signer = new ethers.Wallet(PRIVATE_KEY, provider);

const auditedProjects = new Set();

async function main() {
  const contract = new ethers.Contract(firewallAddress, firewallAbi, signer);

  console.log('正在监听 registerEvent 事件...');

  // 监听 'registerEvent' 事件
  contract.on('registerEvent', async (registeredProject) => {
    // 检查是否已审计
    if (auditedProjects.has(registeredProject)) {
      console.log(`项目 ${registeredProject} 已经审计过，跳过此次审计。`);
      return;
    }

    console.log(`检测到新的注册项目：${registeredProject}`);

    try {
      // 调用 'audit' 函数
      await audit(registeredProject);
      // 标记该项目为已审计
      auditedProjects.add(registeredProject);
    } catch (error) {
      console.error(`调用 audit 函数时出错：${error}`);
    }
  });
}

main().catch((err) => {
  console.error('运行出错：', err);
});
