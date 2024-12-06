// 借贷项目 代币A/B，借贷的数量完全依赖于交易所A中代币对A/B的价格
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProxyForRouter} from "../proxy/proxyForRouter.sol";

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function token0() external view returns (address);

    function token1() external view returns (address);
}

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract SimpleLending {
    // 借贷项目，用户可以通过抵押A token来获取B token
    address public tokenA;
    address public tokenB;
    uint256 public totalAmount_last;
    IUniswapV2Pair public uniswapPool;
    ProxyForRouter router;

    mapping(address => uint256) public loanBalances;

    constructor(
        address _tokenA,
        address _tokenB,
        address _uniswapPool,
        address _routerProxy
    ) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        uniswapPool = IUniswapV2Pair(_uniswapPool);
        router = ProxyForRouter(payable(_routerProxy));
    }

    function getPrice() public view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = uniswapPool.getReserves();
        return
            uniswapPool.token0() == tokenA
                ? reserve1 / reserve0
                : reserve0 / reserve1;
    }

    function requestLoan() external {
        bytes memory data = abi.encodeWithSignature(
            "executeWithDetect(bytes)",
            msg.data
        );
        router.CallOn(data);

        uint256 tokenAPrice = getPrice();
        // 计算用户抵押的代币A的数量
        uint256 collateralAmount = IERC20(tokenA).balanceOf(address(this)) -
            totalAmount_last;
        // 计算接触的代币B的数量
        uint256 amount = collateralAmount * tokenAPrice;

        loanBalances[msg.sender] += amount;
        IERC20(tokenB).transfer(msg.sender, amount);

        totalAmount_last = IERC20(tokenA).balanceOf(address(this));
    }

    function repayLoan(uint256 amount) external {
        loanBalances[msg.sender] -= amount;
        IERC20(tokenA).transferFrom(msg.sender, address(this), amount);
    }
}
