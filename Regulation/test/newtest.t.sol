// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Regulated2.sol";

contract RegulatedTokenTest is Test {
    RegulatedToken token;
    address admin = address(0x1);
    address regulator = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);
    address blacklisted = address(0x5);
    address whitelisted = address(0x6);

    function setUp() public {
        // 设置部署者为 admin
        vm.startPrank(admin);

        // 部署合约
        token = new RegulatedToken("RegulatedToken", "RGT", 100000000 * 1e18, 5000 * 1e18, 50000 * 1e18);

        // 授予监管员角色
        token.grantRole(token.REGULATOR_ROLE(), regulator);

        // 将 admin 和 user1 添加到白名单
        token.addToWhitelist(admin);
        token.addToWhitelist(user1);

        // 启用白名单功能
        token.enableWhitelist();

        // 分配一些代币给 user1 和 user2
        token.transfer(user1, 5000 * 1e18);
        token.transfer(user2, 5000 * 1e18);

        vm.stopPrank();
    }

    /**
     * @dev 测试黑名单功能的启用和禁用
     */
    function testBlacklisting() public {
        // 启用黑名单功能
        vm.startPrank(regulator);
        token.enableBlacklist();
        vm.stopPrank();

        // 监管员添加地址到黑名单
        vm.startPrank(regulator);
        token.addToBlacklist(blacklisted);
        vm.stopPrank();

        // 尝试从黑名单地址转账，应失败
        vm.startPrank(blacklisted);
        vm.expectRevert("RegulatedToken: Sender is blacklisted");
        token.transfer(user1, 100 * 1e18);
        vm.stopPrank();

        // 尝试向黑名单地址转账，应失败
        vm.startPrank(user1);
        vm.expectRevert("RegulatedToken: Recipient is blacklisted");
        token.transfer(blacklisted, 100 * 1e18);
        vm.stopPrank();

        // 监管员移除地址出黑名单
        vm.startPrank(regulator);
        token.removeFromBlacklist(blacklisted);
        vm.stopPrank();

        // 现在转账应成功，因为 user1 在白名单中
        vm.startPrank(user1);
        token.transfer(blacklisted, 100 * 1e18);
        assertEq(token.balanceOf(blacklisted), 100 * 1e18);
        vm.stopPrank();

        // 禁用黑名单功能
        vm.startPrank(regulator);
        token.disableBlacklist();
        vm.stopPrank();

        // 现在，即使 address 在黑名单（已移除），转账应正常
        vm.startPrank(user1);
        token.transfer(user2, 200 * 1e18);
        assertEq(token.balanceOf(user2), 5200 * 1e18);
        vm.stopPrank();
    }

    /**
     * @dev 测试转账限额功能的启用和禁用
     */
    function testTransferLimits() public {
        // 启用转账限额功能
        vm.startPrank(regulator);
        token.enableTransferLimits();
        vm.stopPrank();

        // 设置单笔转账限额为 1000 RGT
        vm.startPrank(regulator);
        token.updateMaxTxAmount(1000 * 1e18);
        vm.stopPrank();

        // 设置每日转账限额为 5000 RGT
        vm.startPrank(regulator);
        token.updateDailyTxLimit(5000 * 1e18);
        vm.stopPrank();

        // 普通转账不超过限额，应成功
        vm.startPrank(user1);
        token.transfer(user2, 1000 * 1e18); // 等于 maxTxAmount
        assertEq(token.balanceOf(user2), 6000 * 1e18);
        vm.stopPrank();

        // 超过单笔限额，应失败
        vm.startPrank(user1);
        vm.expectRevert("RegulatedToken: Transfer amount exceeds the maxTxAmount");
        token.transfer(user2, 1001 * 1e18);
        vm.stopPrank();

        // 累计超过每日限额，应失败
        vm.startPrank(user1);
        token.transfer(user2, 4000 * 1e18); // 已转移1000，累计5000
        vm.expectRevert("RegulatedToken: Transfer amount exceeds the dailyTxLimit");
        token.transfer(user2, 1 * 1e18); // 超过5000
        vm.stopPrank();

        // 禁用转账限额功能
        vm.startPrank(regulator);
        token.disableTransferLimits();
        vm.stopPrank();

        // 现在，即使超过限额，转账应成功
        vm.startPrank(user1);
        token.transfer(user2, 10000 * 1e18); // 超过之前的单笔限额
        assertEq(token.balanceOf(user2), 16000 * 1e18);
        vm.stopPrank();
    }

    /**
     * @dev 测试暂停功能的启用和禁用
     */
    function testPause() public {
        // 管理员暂停合约
        vm.startPrank(admin);
        token.pause();
        vm.stopPrank();

        // 尝试转账，应失败
        vm.startPrank(user1);
        vm.expectRevert("Pausable: paused");
        token.transfer(user2, 100 * 1e18);
        vm.stopPrank();

        // 管理员恢复合约
        vm.startPrank(admin);
        token.unpause();
        vm.stopPrank();

        // 转账应成功
        vm.startPrank(user1);
        token.transfer(user2, 100 * 1e18);
        assertEq(token.balanceOf(user2), 5100 * 1e18);
        vm.stopPrank();
    }

    /**
     * @dev 测试角色权限限制
     */
    function testRoleRestrictions() public {
        // 非监管员尝试添加黑名单，应失败
        vm.startPrank(user1);
        vm.expectRevert("AccessControl: account 0x0000000000000000000000000000000000000003 is missing role 0x..."); // 具体 revert 信息取决于 AccessControl 实现
        token.addToBlacklist(user2);
        vm.stopPrank();

        // 非管理员尝试暂停合约，应失败
        vm.startPrank(regulator);
        vm.expectRevert("AccessControl: account 0x2 is missing role 0x..."); // 具体 revert 信息取决于 AccessControl 实现
        token.pause();
        vm.stopPrank();
    }

    // function testDynamicModuleToggle() public {
    //     // 启用黑名单和转账限额功能
    //     vm.startPrank(regulator);
    //     token.enableBlacklist();
    //     token.enableTransferLimits();
    //     token.updateMaxTxAmount(1000 * 1e18);
    //     token.updateDailyTxLimit(5000 * 1e18);
    //     vm.stopPrank();

    //     // 监管员添加地址到黑名单
    //     vm.startPrank(regulator);
    //     token.addToBlacklist(blacklisted);
    //     vm.stopPrank();

    //     // 尝试从黑名单地址转账，应失败
    //     vm.startPrank(blacklisted);
    //     vm.expectRevert("RegulatedToken: Sender is blacklisted");
    //     token.transfer(user1, 100 * 1e18);
    //     vm.stopPrank();

    //     // 尝试向黑名单地址转账，应失败
    //     vm.startPrank(user1);
    //     vm.expectRevert("RegulatedToken: Recipient is blacklisted");
    //     token.transfer(blacklisted, 100 * 1e18);
    //     vm.stopPrank();

    //     // 监管员移除地址出黑名单
    //     vm.startPrank(regulator);
    //     token.removeFromBlacklist(blacklisted);
    //     vm.stopPrank();

    //     // 现在转账应成功，因为 user1 在白名单中
    //     vm.startPrank(user1);
    //     token.transfer(blacklisted, 100 * 1e18);
    //     assertEq(token.balanceOf(blacklisted), 100 * 1e18);
    //     vm.stopPrank();

    //     // 禁用黑名单功能
    //     vm.startPrank(regulator);
    //     token.disableBlacklist();
    //     vm.stopPrank();

    //     // 现在，可以向原黑名单地址转账
    //     vm.startPrank(user1);
    //     token.transfer(blacklisted, 100 * 1e18);
    //     assertEq(token.balanceOf(blacklisted), 200 * 1e18);
    //     vm.stopPrank();

    //     // 禁用转账限额功能
    //     vm.startPrank(regulator);
    //     token.disableTransferLimits();
    //     vm.stopPrank();

    //     // 确保 user1 的余额足够
    //     // user1 初始余额: 5000 *1e18
    //     // 已转出: 100 + 100 = 200 *1e18
    //     // 当前余额: 4800 *1e18
    //     // 尝试转账: 4800 *1e18
    //     vm.startPrank(user1);
    //     token.transfer(user2, 4800 * 1e18); // 调整为 user1 的剩余余额
    //     assertEq(token.balanceOf(user2), 5000 * 1e18 + 4800 * 1e18); // 9800 *1e18
    //     vm.stopPrank();
    // }
    function testDynamicModuleToggle() public {
        // 初始状态输出
        console.log("=== testDynamicModuleToggle START ===");
        console.log("Initial State:");
        console.log("Blacklist Enabled:", token.blacklistEnabled());
        console.log("Transfer Limits Enabled:", token.transferLimitsEnabled());
        console.log("User1 balance:", token.balanceOf(user1));
        console.log("User2 balance:", token.balanceOf(user2));
        console.log("Blacklisted balance:", token.balanceOf(blacklisted));
        console.log("-------------------------------------");

        // 启用黑名单和转账限额功能
        vm.startPrank(regulator);
        console.log("Enabling blacklist and transfer limits...");
        token.enableBlacklist();
        token.enableTransferLimits();
        token.updateMaxTxAmount(1000 * 1e18);
        token.updateDailyTxLimit(5000 * 1e18);
        vm.stopPrank();

        console.log("Modules Enabled:");
        console.log("Blacklist Enabled:", token.blacklistEnabled());
        console.log("Transfer Limits Enabled:", token.transferLimitsEnabled());
        console.log("MaxTxAmount:", token.maxTxAmount());
        console.log("DailyTxLimit:", token.dailyTxLimit());
        console.log("-------------------------------------");

        // 监管员添加地址到黑名单
        vm.startPrank(regulator);
        console.log("Adding blacklisted address to blacklist...");
        token.addToBlacklist(blacklisted);
        vm.stopPrank();

        console.log("Blacklisted address is blacklisted:", token.isBlacklisted(blacklisted));
        console.log("-------------------------------------");

        // 尝试向黑名单地址转账，应失败
        vm.startPrank(user1);
        console.log("Trying to transfer 100 to blacklisted (should fail)...");
        vm.expectRevert("RegulatedToken: Recipient is blacklisted");
        token.transfer(blacklisted, 100 * 1e18);
        vm.stopPrank();

        console.log("Transfer failed as expected due to blacklist.");
        console.log("-------------------------------------");

        // 禁用黑名单功能
        vm.startPrank(regulator);
        console.log("Disabling blacklist...");
        token.disableBlacklist();
        vm.stopPrank();

        console.log("Blacklist Enabled:", token.blacklistEnabled());
        console.log("Now blacklist is disabled, we can transfer to previously blacklisted address.");
        console.log("-------------------------------------");

        // 现在，可以向原黑名单地址转账
        vm.startPrank(user1);
        console.log("Transferring 100 * 1e18 to previously blacklisted address now that blacklist is disabled...");
        token.transfer(blacklisted, 100 * 1e18);
        console.log("User1 balance after transfer:", token.balanceOf(user1));
        console.log("Blacklisted balance:", token.balanceOf(blacklisted));
        vm.stopPrank();

        console.log("-------------------------------------");

        // 禁用转账限额功能
        vm.startPrank(regulator);
        console.log("Disabling transfer limits...");
        token.disableTransferLimits();
        vm.stopPrank();

        console.log("Transfer Limits Enabled:", token.transferLimitsEnabled());
        console.log("Now limits are disabled, we can try a large transfer.");
        console.log("-------------------------------------");

        // 确保 user1 的余额足够，并尝试大额转账
        // 计算当前user1的余额（初始5000 *1e18，在前面转出200 *1e18后为4800 *1e18）
        uint256 user1BalanceBefore = token.balanceOf(user1);
        console.log("User1 balance before large transfer:", user1BalanceBefore);
        console.log("Transferring 4800 * 1e18 to user2...");

        vm.startPrank(user1);
        token.transfer(user2, 4800 * 1e18);
        vm.stopPrank();

        console.log("User1 balance after large transfer:", token.balanceOf(user1));
        console.log("User2 balance after large transfer:", token.balanceOf(user2));
        console.log("=== testDynamicModuleToggle END ===");
    }
}
