// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "../src/flashloanv3.sol";

address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

contract UniswapV2FlashloanTest is Test {
    IWETH private weth = IWETH(WETH);

    UniswapV3Flashloan private flashloan;

    function setUp() public {
        flashloan = new UniswapV3Flashloan();
    }

    function testFlashloan() public {
        // 换weth，并转入flashloan合约，用做手续费
        weth.deposit{value: 1e18}();
        weth.transfer(address(flashloan), 1e18);

        uint256 balBefore = weth.balanceOf(address(flashloan));
        console2.logUint(balBefore);
        // 闪电贷借贷金额
        uint256 amountToBorrow = 1 * 1e18;
        flashloan.flashloan(amountToBorrow);
    }

    // 手续费不足，会revert
    function testFlashloanFail() public {
        // 换weth，并转入flashloan合约，用做手续费
        weth.deposit{value: 1e18}();
        weth.transfer(address(flashloan), 1e17);
        // 闪电贷借贷金额
        uint256 amountToBorrow = 100 * 1e18;
        // 手续费不足
        vm.expectRevert();
        flashloan.flashloan(amountToBorrow);
    }
}
