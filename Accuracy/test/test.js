const { ethers } = require("hardhat");
require("dotenv").config();

// 配置参数
const RPC_URL = process.env.ALCHEMY_SEPOLIA_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const example_ADDRESS = "0xcbfc7de5b85C135fCC03E313c8e4E6AA2729450C";
const attack_ADDRESS = "0xf3965b267B2589E7E094ba890Ee7c4a6C04C67Ab";
const normal_ADDRESS = "0x40258DAef685606c2E890064c7d28FD7e6b146e1";
const firewall_address = "0x94FE05e79c84E3dE1f876b6612c780c11658B495";

const example_ABI = require("../abi/etherStore.sol/EtherStore.json").abi;
const attack_ABI = require("../abi/attack.sol/Attack.json").abi;
const normal_ABI = require("../abi/normal.sol/Normal_tx.json").abi;
const firewall_ABI = require("../abi/FireWallDeployer.sol/FireWallDeployer.json").abi;

const BLACKLIST_WALLETS = [
    "0xe6511ec12853cf254783e78bf28da1802a6e5753b7514b0109ecea3a69c6ca88",
    "0xcbaded5732a5c36c6a52bea4eb5794b35c6b8448c1cb8182f7213e164a6bddf5",
    "0x0de00752e65532698b75337174989e22826008669d1948ccb7e472f9282dcd39",
    "0x4a13af2f0b04096c08cee993924203d98c1bcd710479cada91bdd2d0595032d3",
    "0xf0c4340dc8d40458165469f133a8d255887cbb5c6b6ab89c5936a79b26e47bd9",
    "0xf3fe3486c7e259db3059854163ae2b7919289b4d45ccee03da2530da23cf93a0",
    "0xea184aa7c55df9bb274d96b11fc74b999a7a891a00f20853360a29ffbd1b4c7a",
    "0xf8c895c77a99fe4f21411801d162e2f2b29c2f3598f7faac73d14b6cc7bd520b",
    "0x8f117863213083bcc4a90629ba05b72d6ef7495253d743ee2c4be2f9ea23ce04",
    "0x2c8c302d16fbd34b95738dffa1cd60aa30593938a4ba44cc5cdf8a1975916f04",
    "0xa1cd7c758c094a6b4df2bcf60fa41cdc3c1905a07da1c73483feb3b76424c53c",
    "0x36693134f3b8380fb490141cc584d3ea638407de1dab24a7ca8bf2b852e4ec55",
    "0x4f5431e64d9cffd944fd176337127d7284bdf172062bcdcb4c53ab36b8df9c5b",
    "0xd10a05295371c66f197f93512bc3a5901b125bf423b23022b06f367e74a9c84c",
    "0x48e12f85928e110bb322d1a73a736758364b8899ec72401b14f6b5c5eff15336",
    "0xd41402aeee476bf4fbecb89823e534c064197ccb9a344d9b349fa5a124d0b3ed",
    "0xd15f88f9de1dd1453f0853844f38cdf832d43df136627ed533faea092297871c",
    "0xb85b0d70878f66dee690ab215d8c2d4a9dc80a93d5eefc389546a35d8007133e",
    "0xa1c9c657427e6f1d5b96589939ed41978a36168228021b9b1a0bc259d7bcbf83",
    "0x3d68aa6a79423fd70268cdd4cafa5f3512550a1ec4e0b9e0dc1880787ae285f6",
    "0xbc2cd08105f3b489a4da645f2a8b211c1cce7ad28f61b11cf990b5894c94ce03",
    "0xcf1a76794f13f95c7fc16d7fee5c7f04d90c2db0c296bc59c1a86b7a25d228b0",
    "0x900d6bfcc5a12b3861f8be8c269e4c3a685b063d7efb4979fb3ece579096c82a",
    "0xecdc5d1b190164afac1d9fb1b32238fb13abc6bb9088cc4d7485cb27d1b38118",
    "0x81977d48f451cfe5703d636b034ad73a4343248d7935e42b6d57ebadb24ecfb7",
    "0x20b41fa7a8ac6111bbdf776594df1055fbbf3e4a9b8bece052fecdd2e858a396",
    "0x8541d3c6895c6c2b4df2ce11587c3ea55513833d5bec81f4877c3b708e4cd9c3",
    "0x227a1cad460f5e8d0e55065412fb52641fd868751f1ca62043a7d86da68ebcb5",
    "0x9b82f2acf1841f0a9e4cfbe26931ceb7188e7dbd2e980d62cc9bc3f4556a6e39",
    "0x1e27ccbc03be12ac9f28eae39d78e33eb79c6a52d33896548ac8a8c3953c073e",
    "0x200f3ba4668300a145b1def532c3e8c3715a14f4500d0ec11401cd44dd20a6b5",
    "0x021d70104770b0135dabd68f484283bc65b0562bb9b647d97039dd9fdd4b380b",
    "0x1a6f157bba30b002c453b8854fe46cefc241fce87f8f94a060403c9b7aeeb9b2",
    "0xdc419f919b829de2dae36ea2cfb8e02ad3f7960d5166a72ee59bd6aa371800e2",
    "0x5c65188e58d9e21c8d71fbc858fd1d922b61b5b297fc0a645f2c2c00de279157",
    "0xdedcd3103bf85f26064f635c019529922267b2addb546fa252a8bc88d4d00846",
    "0x4aee46bf0233efbc4a1b72b83f7efdb6ca0b2f2016dd292554d866558e556c17",
    "0x78643a48de145d184244fbac103e506326a93465524c5faf4a71cab1c561e537",
    "0x3c1c3b2449a2b094d946dbf25f26bb7f07c9bc9a2fc97cb4911bd597e5e73294",
    "0x07af5da60f66ffe159b9d41d0f40aa11d9e8f6b2a6bd7b946630b7a927f6fc96",
    "0x063ba0df4d2bf83a503bf1cbc22ab528a3e71ebac65de33efdadd8dd680d77c7",
    "0x47b6fec81e4a80b18319d12620c9250256c29075fe0a5fd270017a1bd1cb4d08",
    "0xa935027cafd729e6a3a1672972fda3ae052548401840573ddde211e5c9c930dc",
    "0x9643765c131d286e254b698712c97c023c7f0598b441e53b9cd19035090984a8",
    "0xbc0727e006f610054120b338ff04ae7d36015ef151589ce8c9e9e7eb65ee3f18",
    "0x4bfe7aed908c8c4de2ba037a1f9c7321b19918d4a281068d72051cf0a4638918",
    "0x2ee1f38e284ed7716ac93d657edc837b41f840e4fba6a33cb049901412412351",
    "0xdd850cf8badea94b07cf9b0bcf49ab25a58a529ed5c7a40aece9258c11606d12",
    "0xc5c4a5b8ddeeeb3b8f9af42c4458ac9baa838d7bff92fc6ec2abc81b581508a5",
    "0xd8097488eab710446a5d461913bdf3b037ec628e4585b0832492f88da2ffe698",
];
const BLACKLIST_ADDRESSES = [
    "0x9eD3edCc47aaF7FEE9E3801Ae3e13d23e1B3a164",
    "0x7861a5F0D3F1fe7a47306fD66ca78328D492A4aF",
    "0x97DBb872c6462Dc78f05Ab858f485728F02e20fe",
    "0xC2062458c36eD68CffA7e2060E3d7E4671422159",
    "0x0E204e50788f4f17eCcA2B0d7C5A2500C6473a65",
    "0x49A548D4d744545dbc28807A5B4b4d63fbCF7960",
    "0xdB6cd0FF356118bFb031A928c1FdE161Fb040262",
    "0x2e3B5e87CF76ad66ab28d1A822104885725685ae",
    "0xd1943CE835beB37E0e767037d5a149dcA7EA5D9e",
    "0x5c1E5659ccDfbbD7F2F93A6311AeEC7b2C304801",
    "0x60D5c28eace1799d5f6da9b498e940D95a4CCA4D",
    "0x08CaF6AEb6B2A56b38d7b88AEb11332E6e21F4aC",
    "0xa8447E3fF8d7015d4C653Fd28c0528A5E05dB66d",
    "0x723E26f2A06Ba72d2abB20973DE05711075a4Df0",
    "0x1e42C1373dc1215B6F8dE6DDCfF36add9798A82d",
    "0xAcF1785A4cAbb00165766B886D7aa23666D1c5E3",
    "0x3D70A583C540fFab2a574692B1f3F766E19d3538",
    "0x09ffE35E34Bd4a9530Bb0E2ad994C4bB32D85F02",
    "0x9ee82A9aC69F663ca83129BF9009A9B23e2CA9c0",
    "0xCA0dC579461FbDBdC8F568dc18F6acBa4aE173f2",
    "0x166b3294E1Cb4950b304404eBB0A7E209a80D7E2",
    "0x282b2Fe05E27c7A77c73103e85A7bFbCF3FDa66b",
    "0xb50184b00D6BeC6d8B7Aed5a5e63567D6E142123",
    "0xe29E5c579183A9D4610c72601D360fe3E196243f",
    "0x1f0A7078dfD5D97e849497c74a6bD799BD846b05",
    "0x8d819582d2C95EEeFa18219e9269e4d7C2Ac3bA6",
    "0x2CD434e66BD60C2a35F2549d2B5833377e5c4Be9",
    "0xCC5D2B44E6e97C7529EFc94De8d1b7Aaf5CC4D05",
    "0xf5f9CD582134EFB91E8b87b981Cf79bC268C9369",
    "0xaCb519c7FE723B37d53cFd2ceD6A2FB1a63497A1",
    "0x0B05FE62316C2fe0C6d6219857dba7DF0489EA89",
    "0xE1F450C343f26c60FebF1fCB50C820310522A3cA",
    "0x259F9Ab17385B62b8d219E146DC87e763a1f7bF1",
    "0xFB4Aa95581B70F5fd0B46D706E37069fb90c832C",
    "0x50dDa5b72F0fea884299ED5F2f1cc12D27ceD579",
    "0xCf89FDd411501603830179d33176333A7bd884d8",
    "0xe17b2fb940B1BBd64c7b868E44BFeB5B162ed6a1",
    "0x9A457AD745886D6b7Ef67C010CBe34C87471711c",
    "0x7f41449c0Fab85346EEd6ed2D97477fdB1D8418c",
    "0x4e390C3c1072155Ed6481D9A4F43826f582BB406",
    "0x562554715f2504102eE1c82e6Fcf5e027C79EcEb",
    "0xcA3C17e55A83A096cFc382101E56cC6f7f0ab982",
    "0xeaFAc277b578998a1e2C1C17da4824Cd8BE9A60F",
    "0x55A843085abE81e1A3A94FA719D0074fD90091F9",
    "0x9Dc82564D054186CC0264445c3a5Fa18837cDBFd",
    "0x79Dc1B1DE8D1004a5A2DfbE009C964d50ce4E4e6",
    "0x707fe02F65A4A31e054865ec98a1520A5aa99b98",
    "0xcE3CCF1a87FfC61B9fc5AcF0BB3AF225e5191a47",
    "0x096Ef0840A1560A1388D908db5853299eA1ccdDb",
    "0x96b67A3CFa8B7e998BA599BAB55c269f4C481fB2",
];

const accounts_address = [
    "0x005dD7a293ec8290D814bA45e6D4B353EDD8c7a6",
    "0x9eB575306EcDDDDd3B1C3E373C8a3E64A33B76a9",
    "0x0c26b1FDDA6C54b4A677B7323650fD35c4DeDa9b",
    "0x0e39300BbF8e222E42fCaE619D055b0437C0D286",
    "0xBda23dc7a72A0743C2cBc91617ad194D61f6C9E4",
    "0x53a34Fd7EA34956651158f704f248033E6CB3783",
    "0xa22390f8bB5d55330f89be256F5DD88e4fB81A72",
    "0x332c644b83A51c7497aeda4f7c06B0842B18A7B0",
    "0xFF7694d4d31d83d12646B08EAD82C1428926a071",
    "0x941571aEc6442a0B0Cc7Afda9b2236e546f79ddb",
];
const accounts_Pk = [
    "0xf47f02241e52eb9936b40f5937c21c190f29f928c560bf29e743a4194f141753",
    "0xae0b8590c5db4c287ae89b4b52ce6732f64180e063ab07a2ec67f091f2273c81",
    "0xfba53953ad48c733f02e324edcd7fc618695e4dfc328ecfbbad8acafdd5c085f",
    "0x12e7e5d9212dc93c35f566bd3ec686b36409ca5dd7c85685f7dbbdc43205de3a",
    "0xf08d9c152899d4b7f03392d719e7cf578c02fff33d76e975b71b4d43c84e1178",
    "0x9732b4e36f283aa22315aa613ceb12101de5a2965e8923e489c2902c04632f56",
    "0x852c4b1ef3ea1db302d0f16bc06d1ee9555e6e22390a34d4e73a40292e04477b",
    "0x635189434206a4551bf910773e651c6f92abc8fe6c8d526f8c3f60e00dcb4036",
    "0xb44c5b85baae7db9745ecc5c18b26ae4ba37b4abe9aa242d2381f314caabb9e9",
    "0xc965ab71b71ea628cdef8f5ea18a169182f20114b595c3f98933ed2ed8abce41",
];
const accounts = [];

let attackFailureCount = 0; // 记录攻击交易失败数
let normalSuccessCount = 0; // 记录正常交易成功数
const attackTransactionTimes = []; // 攻击交易时间
const normalTransactionTimes = []; // 正常交易时间


async function setBlacklist_onchain(firewall_contract, signer) {
    try {
        console.log("开始设置黑名单...");

        // 调用 batch_setblack 方法
        const tx = await firewall_contract.connect(signer).batch_setblack(example_ADDRESS, BLACKLIST_ADDRESSES);
        console.log("交易已发送，等待确认...");

        // 等待交易被确认
        await tx.wait();
        console.log("黑名单设置成功！");
    } catch (error) {
        console.error("设置黑名单失败：", error);
    }
}


async function initial_blacklist_balance(signer) {
    // 遍历地址列表，逐个转账
    for (let i = 0; i < BLACKLIST_ADDRESSES.length; i++) {
        const recipient = BLACKLIST_ADDRESSES[i];
        try {
            console.log(`start ${i} transfer`);
            console.log(`Transferring 0.01 ETH to ${recipient}...`);
            const tx = await signer.sendTransaction({
                to: recipient,
                value: ethers.parseEther("0.01"),
            });
            await tx.wait();
            console.log(`Transaction to ${recipient} completed!`);
        } catch (error) {
            console.error(`Failed to transfer to ${recipient}:`, error);
        }
    }
}

async function transferToRandomAccounts(signer) {

    for (let i = 0; i < accounts_address.length; i++) {
        const recipient = accounts_address[i];
        try {
            console.log(`Transferring 0.01 ETH to ${recipient}...`);
            const tx = await signer.sendTransaction({
                to: recipient,
                value: ethers.parseEther("0.1"),
            });
            await tx.wait();
            console.log(`Transaction to ${recipient} completed!`);
        } catch (error) {
            console.error(`Failed to transfer to ${recipient}:`, error);
        }
    }
}


async function main() {
    // 1. 初始化 provider 和 signer
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const signer = new ethers.Wallet(PRIVATE_KEY, provider);

    // 2. 连接到合约
    const example_contract = new ethers.Contract(example_ADDRESS, example_ABI, signer);
    const attack_contract = new ethers.Contract(attack_ADDRESS, attack_ABI, signer);
    const normal_contract = new ethers.Contract(normal_ADDRESS, normal_ABI, signer);
    const firewall_contract = new ethers.Contract(firewall_address, firewall_ABI, signer);

    // 初始化测试账户资金
    // await initial_blacklist_balance(signer);
    // await transferToRandomAccounts(signer);

    // test(provider, normal_contract);
    // test(provider, attack_contract);


    // 执行交易
    await executeReentrancyAttacks(provider, attack_contract);
    await executeBlacklistTransactions(provider, normal_contract);
    await executeNormalTransactions(provider, normal_contract);

    // 打印统计信息
    console.log("=== Transaction Summary ===");
    console.log(`Attack transactions failed: ${attackFailureCount}`);
    console.log(`Normal transactions succeeded: ${normalSuccessCount}`);
    // 打印 attackTransactionTimes 数组的每个值
    console.log("Attack transaction times:");
    for (let i = 0; i < attackTransactionTimes.length; i++) {
        console.log(`${i + 1}: ${attackTransactionTimes[i]} ms`);
    }

    // 打印 normalTransactionTimes 数组的每个值
    console.log("Normal transaction times:");
    for (let i = 0; i < normalTransactionTimes.length; i++) {
        console.log(`${i + 1}: ${normalTransactionTimes[i]} ms`);
    }
}



// 执行 50 次重入攻击
// 正常账户执行五次参数不同的重入攻击，一共十个账户
async function executeReentrancyAttacks(provider, attackContract) {
    console.log("Executing 50 reentrancy attacks with 10 accounts...");
    let counter = 0; // 参数递增计数器
    for (let i = 0; i < accounts_Pk.length; i++) {
        const wallet = new ethers.Wallet(accounts_Pk[i], provider) // 当前账户
        const signerAttackContract = attackContract.connect(wallet); // 用当前账户连接合约

        for (let j = 0; j < 5; j++) {
            const startTime = Date.now(); // 记录开始时间
            try {
                console.log(
                    `Account ${wallet.address} calling attack(${counter})...`
                );
                const tx = await signerAttackContract.attack(counter, {
                    value: ethers.parseEther("0.0001")
                });
                await tx.wait(2);

                const endTime = Date.now(); // 记录结束时间
                attackTransactionTimes.push(endTime - startTime); // 记录时间
                console.log(
                    `Attack ${counter} completed successfully by ${wallet.address}`
                );
            } catch (error) {
                attackFailureCount++; // 记录失败数
                console.error(
                    `Attack ${counter} failed by ${wallet.address}:`,
                    error
                );
            }
            counter++; // 每次递增参数
        }
    }
}

// 执行 50 次黑名单交易
async function executeBlacklistTransactions(provider, normalContract) {
    console.log("Executing 50 blacklist transactions...");

    for (let i = 0; i < BLACKLIST_WALLETS.length; i++) {
        const wallet = new ethers.Wallet(BLACKLIST_WALLETS[i], provider) // 从 BLACKLIST_WALLETS 中获取钱包并连接 provider
        const signerNormalContract = normalContract.connect(wallet); // 用当前钱包连接合约

        const startTime = Date.now(); // 记录开始时间
        try {
            console.log(
                `Blacklisted wallet ${wallet.address} calling sendTx(100)...`
            );

            // 调用 normal_contract 的 sendTx 函数
            const tx = await signerNormalContract.sendTx(110, {
                value: ethers.parseEther("0.0001")
            });

            await tx.wait(2);

            const endTime = Date.now(); // 记录结束时间
            attackTransactionTimes.push(endTime - startTime); // 记录交易时间
            console.log(
                `Transaction completed successfully by blacklisted wallet ${wallet.address}`
            );
        } catch (error) {
            attackFailureCount++; // 记录失败数
            console.error(
                `Transaction failed for blacklisted wallet ${wallet.address}:`,
                error
            );
        }
    }
}

// 执行 100 笔正常交易
async function executeNormalTransactions(provider, normalContract) {
    console.log("Executing 100 normal transactions...");

    let parameter = 100; // 参数从 100 开始递增

    for (let i = 0; i < accounts_Pk.length; i++) {
        const wallet = new ethers.Wallet(accounts_Pk[i], provider); // 用当前账户连接 provider
        const signerNormalContract = normalContract.connect(wallet); // 用当前账户连接合约

        for (let j = 0; j < 10; j++) {
            const startTime = Date.now(); // 记录开始时间
            try {
                console.log(
                    `Account ${wallet.address} calling sendTx(${parameter})...`
                );

                // 调用 normal_contract 的 sendTx 函数
                const tx = await signerNormalContract.sendTx(parameter, {
                    value: ethers.parseEther("0.0001")
                });

                await tx.wait(2);

                const endTime = Date.now(); // 记录结束时间
                normalTransactionTimes.push(endTime - startTime); // 记录时间
                normalSuccessCount++; // 记录成功数

                console.log(
                    `Transaction with parameter ${parameter} completed by ${wallet.address}`
                );
            } catch (error) {
                console.error(
                    `Transaction with parameter ${parameter} failed by ${wallet.address}:`,
                    error
                );
            }
            parameter++; // 每次递增参数
        }
    }
}

async function test(provider, contract) {
    const black_wallet = new ethers.Wallet(BLACKLIST_WALLETS[0], provider);
    console.log("test address is :", black_wallet.address);
    const normal_wallet = new ethers.Wallet(accounts_Pk[0], provider);
    console.log("test address is :", normal_wallet.address);


    const signerAttackContract = contract.connect(normal_wallet);
    const startTime = Date.now();
    const tx = await signerAttackContract.sendTx(110, {
        value: ethers.parseEther("0.0001") // 发送 0.0001 ETH
    });
    // const tx = await signerAttackContract.attack(1, {
    //     value: ethers.parseEther("0.0001") // 发送 0.0001 ETH
    // });
    await tx.wait();

    const endTime = Date.now();

    const useTime = endTime - startTime;
    console.log("useTime is :", useTime);

}

main().catch((error) => {
    console.error("Error:", error);
});
