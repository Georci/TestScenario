// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/RegulatedToken.sol";

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
        token = new RegulatedToken("RegulatedToken", "RGT", 100000000 * 1e18, 5000 * 1e18, 500000 * 1e18);

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

    function testBlacklisting() public {
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
    }

    function testWhitelisting() public {
        // 监管员添加地址到白名单
        vm.startPrank(regulator);
        token.addToWhitelist(whitelisted);
        vm.stopPrank();

        // 启用白名单逻辑（通过 whitelistEnabled)

        // 非白名单地址尝试转账，应失败
        vm.startPrank(user1);
        vm.expectRevert("RegulatedToken: Both sender and recipient are not whitelisted");
        token.transfer(user2, 100 * 1e18);
        vm.stopPrank();

        // 白名单地址可以发送代币
        vm.startPrank(whitelisted);
        token.transfer(user1, 100 * 1e18);
        assertEq(token.balanceOf(user1), 5100 * 1e18);
        vm.stopPrank();

        // 白名单地址可以接收代币
        vm.startPrank(user1);
        token.transfer(whitelisted, 100 * 1e18);
        assertEq(token.balanceOf(whitelisted), 100 * 1e18);
        vm.stopPrank();
    }

    function testTransferLimits() public {
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
    }

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

    function testRoleRestrictions() public {
        // 非监管员尝试添加黑名单，应失败
        vm.startPrank(user1);
        vm.expectRevert();
        token.addToBlacklist(user2);
        vm.stopPrank();

        // 非管理员尝试暂停合约，应失败
        vm.startPrank(regulator);
        vm.expectRevert();
        token.pause();
        vm.stopPrank();
    }

    function testWhitelistToggle() public {
        // 监管员禁用白名单
        vm.startPrank(regulator);
        token.disableWhitelist();
        vm.stopPrank();

        // 现在，非白名单地址也可以转账
        vm.startPrank(user2);
        token.transfer(user1, 100 * 1e18);
        assertEq(token.balanceOf(user1), 5100 * 1e18);
        vm.stopPrank();

        // 监管员启用白名单
        vm.startPrank(regulator);
        token.enableWhitelist();
        vm.stopPrank();

        // 再次尝试转账，应要求至少一个地址在白名单中
        vm.startPrank(user2);
        vm.expectRevert("RegulatedToken: Both sender and recipient are not whitelisted");
        token.transfer(user1, 100 * 1e18);
        vm.stopPrank();
    }
}
