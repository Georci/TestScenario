// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceCleaningContract {
    // record a token price and it's dex info
    struct DexInfo {
        address pool;
        // 一般来说指默认价格高的那种代币，如ETH / USDT，默认为ETH
        address token;
        // 在当前代币对中，该代币的价格
        int256 price;
        // 一般来说指价格低的代币，如ETH / USDT，默认为USDT
        address otherToken;
        // 价格低的代币价格
        int256 otherPrice;
        // 该交易所的交易数量
        uint8 txAmount;
        // 是否启用当前交易所
        bool isEnabled;
    }

    function addDexInfo(
        address _oracle,
        address _pool,
        address _token,
        address otherToken,
        uint8 _txAmount
    ) external;

    function updateDexInfo(
        address _oracle,
        uint8 index,
        uint8 _txAmount,
        address _pool,
        bool _isEnabled
    ) external;

    function getDexInfo(
        address _oracle,
        uint8 index
    ) external returns (DexInfo memory);

    function setTokenPriceForOneDex(
        address _oracle,
        address _needToken,
        uint8 index
    ) external;

    function calculateRealPrice(
        address _oracle,
        address _needToken
    ) external returns (int256);
}
