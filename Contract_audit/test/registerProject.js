const { ethers } = require("hardhat")
require("dotenv").config();

const RPC_URL = process.env.ANVIL_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

// 合约地址和 ABI
const firewallAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const firewallAbi = require("../out/Utils.sol/FireWallDeployer.json").abi;
const provider = new ethers.JsonRpcProvider(RPC_URL);
const signer = new ethers.Wallet(PRIVATE_KEY, provider);
const targetContracts = [
    "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
    "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
    "0x0165878A594ca255338adfa4d48449f69242Eb8F",
    "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",
    "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
    "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318",
    "0x610178dA211FEF7D417bC0e6FeD39F05609AD788",
    "0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e",
    "0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0",
    "0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82"
]

async function main() {
    // 创建合约实例，使用 signer 来发送交易
    const contract = new ethers.Contract(firewallAddress, firewallAbi, signer);

    // 定义其他固定参数
    const deployerAddress = signer.address; // 当前钱包地址
    const targetFunc = "0xd96073cf"; // 目标函数的选择器，如 bytes4(keccak256("functionName()"))
    const params = ["1", "2"]; // 示例参数
    const enableModules = ["0xa513E6E4b8f2a923D98304ec87F64353C4D5C853"]; // 启用的模块地址

    // 遍历 targetContracts 数组
    for (let i = 0; i < targetContracts.length; i++) {
        const targetContract = targetContracts[i]; // 获取当前目标合约地址

        console.log(`正在注册目标合约：${targetContract}`);

        // 调用合约的 `register` 函数
        const tx = await contract.register(
            targetContract,
            deployerAddress,
            targetFunc,
            params,
            enableModules
        );

        console.log("Transaction sent. Waiting for confirmation...");
        await tx.wait(); // 等待交易确认
        console.log(`Transaction confirmed for ${targetContract}: ${tx.hash}`);
    }

    console.log("所有目标合约的注册已完成。");
}

main().catch((err) => {
    console.error('运行出错：', err);
});

async function get_A(contract) {
    const a = await contract.a();
    console.log("a is :", a);
}