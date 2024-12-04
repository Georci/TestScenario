//SPDX-License-Identifier: MIT
import "../OnchainOracle/Interface/IUniswapV2Pair.sol";
import "../OnchainOracle/Interface/IUniswapV2ERC20.sol";
import "../OnchainOracle/Interface/IERC20.sol";
import "../OnchainOracle/libraries/FixidityLib.sol";
import "../Interface/IPriceCleaningContract.sol";
import "../../../lib/forge-std/src/Test.sol";

// TODO:gas优化
pragma solidity ^0.8.0;

contract PriceManipulationPrevention {
    using FixidityLib for *;

    uint8 public constant DECIMALS = 24;

    address owner;

    modifier OnlyOwner() {
        require(msg.sender == owner);
        _;
    }

    address proxyPriceCleanContract;

    function initialize(
        address _owner,
        address _proxyPriceCleanContract
    ) public {
        owner = _owner;
        proxyPriceCleanContract = _proxyPriceCleanContract;
    }

    // 结算价格信息
    struct DexInfo {
        address poolOrProject; // 金融结算使用代币对地址或者是价格源项目地址(包括一些链上、链下预言机等)
        address token; // 金融结算的代币
        address otherToken; // 计算价格的另一种代币
        bool isfromdex; // 金融结算依赖的价格是否来自pool
        int256 deviationThreshold; // 允许的价格偏差，是正常情况下所被允许 priceDifference / realPrice 最大的值，默认24位小数
        address oracle; // 真实价格使用的oracle合约
    }
    // 项目地址 => 项目中的函数 => 结算价格信息
    mapping(address => mapping(bytes4 => DexInfo[])) funcToDexInfos;
    // 项目地址 => 项目中的函数 => 是否启用保护
    mapping(address => mapping(bytes4 => bool)) isEnableProtection;

    /**
     * @dev 获取受保护项目特定函数进行金融结算所使用的价格信息
     * @param data project 受保护项目
     * @param data func_selector 进行金融结算的函数
     * @param data _pool 使用的币对地址或者是价格源项目地址
     * @param data _token 进行金融结算的代币
     * @param data _otherToken 计算价格的另一种代币
     * @param data _deviationThreshold 项目方允许金融结算时代币价格与真实价格的最大差值
     * @param data _deviationThresholdDecimals 项目方设置的代币价格的精度
     */
    // Ken: we don't set price here, because the price must be set when it be use.
    function setInfo(bytes calldata data) external {
        (
            address project,
            bytes4 func_selector,
            uint8 dexIndex,
            address _poolOrProject,
            address _token,
            address _otherToken,
            bool _isfromdex,
            int256 _deviationThreshold,
            uint8 _deviationThresholdDecimals,
            address _oracle
        ) = abi.decode(
                data,
                (
                    address,
                    bytes4,
                    uint8,
                    address,
                    address,
                    address,
                    bool,
                    int256,
                    uint8,
                    address
                )
            );
        DexInfo[] storage dexInfoArray = funcToDexInfos[project][func_selector];
        if (dexInfoArray.length <= dexIndex) {
            // 扩展数组长度
            while (dexInfoArray.length <= dexIndex) {
                dexInfoArray.push();
            }
        }

        // 安全地访问 dexInfoArray[dexIndex]
        dexInfoArray[dexIndex].poolOrProject = _poolOrProject;
        dexInfoArray[dexIndex].token = _token;
        dexInfoArray[dexIndex].otherToken = _otherToken;
        dexInfoArray[dexIndex].oracle = _oracle;
        dexInfoArray[dexIndex].isfromdex = _isfromdex;

        // 设置偏差
        if (_deviationThresholdDecimals != DECIMALS) {
            _deviationThreshold = FixidityLib.convertFixed(
                _deviationThreshold,
                _deviationThresholdDecimals,
                DECIMALS
            );
        }
        dexInfoArray[dexIndex].deviationThreshold = _deviationThreshold;

        isEnableProtection[project][func_selector] = true;
    }

    /**
     * @dev 查看某个受保护项目对应函数中设置的dexInfo
     * @param _project 受保护项目地址
     * @param _funcSelector 受保护函数
     * @param index 要查询的dexInfo索引
     */
    function getDexInfos(
        address _project,
        bytes4 _funcSelector,
        uint8 index
    ) external view returns (DexInfo memory dexInfo) {
        dexInfo = funcToDexInfos[_project][_funcSelector][index];
    }

    /**
     * @dev 查看某个受保护项目对应函数是否启用了价格操纵防护
     * @param _project 受保护项目地址
     * @param _funcSelector 受保护函数
     */
    function getIsEnableProtection(
        address _project,
        bytes4 _funcSelector
    ) external view returns (bool isEnable) {
        isEnable = isEnableProtection[_project][_funcSelector];
    }

    /**
     * @dev 返回某个受保护项目受保护函数的source个数
     * @param project 受保护项目地址
     * @param func_selector 受保护函数
     */
    function getNextDexIndex(
        address project,
        bytes4 func_selector
    ) external view returns (uint256) {
        return funcToDexInfos[project][func_selector].length;
    }

    function removeInfo(bytes calldata data) external {
        (address project, bytes4 func_selector) = abi.decode(
            data,
            (address, bytes4)
        );
        isEnableProtection[project][func_selector] = false;
    }

    /**
     * @notice 当前我们对任意交易所中的价格都采用瞬时价格以及x * y = k的方式来计算
     * @param pool 当前的代币对地址
     * @param token 需要获取价格的代币
     * @return price 指定代币的价格，以另一代币单位计
     * todo!:Optimize the interface format, not all exchanges are the same as IUniswapV2Pair
     */
    function getPriceFromDex(
        address pool,
        address token
    ) public view returns (int256 price) {
        address token0 = IUniswapV2Pair(pool).token0();
        address token1 = IUniswapV2Pair(pool).token1();

        uint token0_balance = IERC20(token0).balanceOf(pool);
        uint token1_balance = IERC20(token1).balanceOf(pool);

        uint8 token0_decimals = IERC20(token0).decimals();
        uint8 token1_decimals = IERC20(token1).decimals();

        // Ken: Because the decimals of each ERC20 token are different, they need to be standardized.
        // 标准化代币数量到24个小数位
        int256 normalized_token0_balance;
        int256 normalized_token1_balance;
        if (token0_decimals != DECIMALS) {
            normalized_token0_balance = FixidityLib.convertFixed(
                int256(token0_balance),
                token0_decimals,
                24
            );
        } else {
            normalized_token0_balance = int256(token0_balance);
        }

        if (token1_decimals != DECIMALS) {
            normalized_token1_balance = FixidityLib.convertFixed(
                int256(token1_balance),
                token1_decimals,
                24
            );
        } else {
            normalized_token1_balance = int256(token1_balance);
        }

        // 确保价格计算的正确性
        if (token == token0) {
            price = FixidityLib.divide(
                normalized_token1_balance,
                normalized_token0_balance
            );
        } else if (token == token1) {
            price = FixidityLib.divide(
                normalized_token0_balance,
                normalized_token1_balance
            );
        } else {
            revert("Requested token is not part of the pair");
        }
        console.log("token price in this pool is:", uint256(price));
        return price;
    }

    /**
     * @notice 从非dex处价格源获取价格
     * @param project 金融结算获取价格的来源地址
     * @param data 进行金融结算时使用的方法
     * @param priceDataOffset The byte offset where price data starts
     * @param priceDataLength The length in bytes of the price data
     */
    // TODO:1.有无更合理的方式去获取source价格(直接使用枚举的方式，记录主流的get source，枚举可以考虑砖石代理，动态添加) 2.是否需要考虑其他交易所接口方法
    function getPriceFromSource(
        address project,
        bytes memory data,
        uint256 priceDataOffset,
        uint256 priceDataLength,
        // 代币本身的decimals不一定是价格源的decimals
        uint8 priceDecimals
    ) public returns (int256 price) {
        (bool success, bytes memory returndata) = project.call(data);
        require(success, "get price from source failed");

        // Ensure that the returndata is long enough
        require(
            returndata.length >= priceDataOffset + priceDataLength,
            "Returned data too short for specified offset and length"
        );
        uint256 priceUint;
        // 提取对应的32字节数据
        assembly {
            // 计算价格数据在 returndata 中的起始位置
            let start := add(returndata, add(32, priceDataOffset))
            // 加载数据
            priceUint := mload(start)
            // 如果 priceDataLength 小于 32，进行右移以获取正确长度的数据
            let shift := sub(32, priceDataLength)
            priceUint := shr(mul(8, shift), priceUint)
        }

        if (priceDecimals != DECIMALS) {
            price = FixidityLib.convertFixed(
                int256(priceUint),
                priceDecimals,
                DECIMALS
            );
        } else {
            price = int256(priceUint);
        }
        return price;
    }

    // getRealPrice, compare
    /**
     * @notice 对当前项目的金融结算进行价格检查
     * @param project 受防火墙保护的项目地址
     * @param args 参数
     * @param data 受防火墙保护的函数签名
     */
    function detect(
        address project,
        string[] memory args,
        bytes memory data
    ) external returns (bool) {
        // 如果没有启动该防护模块
        if (!isEnableProtection[project][bytes4(data)] == true) {
            return true;
        }

        DexInfo[] storage dexInfos = funcToDexInfos[project][bytes4(data)];
        require(dexInfos.length > 0, "No DexInfo found for this function");

        for (uint8 i = 0; i < dexInfos.length; i++) {
            require(
                dexInfos[i].deviationThreshold != 0,
                "You need to set deviationThreshold first"
            );
            require(dexInfos[i].poolOrProject != address(0), "error address");

            // update Financial Settlement price
            int256 updatedPrice;
            if (dexInfos[i].isfromdex == true) {
                updatedPrice = getPriceFromDex(
                    dexInfos[i].poolOrProject,
                    dexInfos[i].token
                );
            } else {
                uint256 offset = 0x44; // 十六进制的0x44转换为十进制
                // 确保偏移量小于数据长度以防止运行时错误
                require(offset <= data.length, "Offset out of bounds");
                // 创建一个新的bytes数组存储从偏移之后的数据
                bytes memory actualPriceData;
                assembly {
                    // 计算新数组的长度
                    let _newLength := sub(mload(data), offset)
                    // 为新的字节数据分配内存空间
                    actualPriceData := mload(0x40) // 加载free memory pointer
                    mstore(actualPriceData, _newLength) // 设置新字节数组的长度

                    // 从原始数据复制字节到新的内存位置
                    let _src := add(data, add(offset, 0x20))
                    let _dest := add(actualPriceData, 0x20)
                    for {
                        let _i := 0
                    } lt(_i, _newLength) {
                        _i := add(_i, 0x20)
                    } {
                        mstore(add(_dest, _i), mload(add(_src, _i)))
                    }
                    // 更新free memory pointer
                    mstore(0x40, add(add(actualPriceData, 0x20), _newLength))
                }

                console.logBytes(actualPriceData);
                (
                    address priceSource,
                    bytes memory call_data,
                    uint256 priceDataOffset,
                    uint256 priceDataLength,
                    uint8 priceDecimals
                ) = abi.decode(
                        actualPriceData,
                        (address, bytes, uint256, uint256, uint8)
                    );
                // Now use the offset and length to access the actual price data
                updatedPrice = getPriceFromSource(
                    priceSource,
                    call_data,
                    priceDataOffset,
                    priceDataLength,
                    priceDecimals
                );
                console.log("complete decode");
            }

            // get real price
            bytes memory callData = abi.encodeWithSignature(
                "getRealPriceByModule(address,address)",
                dexInfos[i].oracle,
                dexInfos[i].token
            );
            (bool success, bytes memory returndata) = proxyPriceCleanContract
                .call(callData);
            require(success, "Call failed");

            // 解码返回的数据
            int256 realPrice = abi.decode(returndata, (int256));
            console2.log("Your current settlement price is :", updatedPrice);
            console2.log("realPrice is:", int256(realPrice));

            int256 priceDifference = FixidityLib.abs(realPrice - updatedPrice);
            priceDifference = FixidityLib.divide(priceDifference, realPrice);
            console2.log("current priceDifference is :", priceDifference);
            console2.log(
                "allowed priceDifference is :",
                dexInfos[i].deviationThreshold
            );

            if (priceDifference > dexInfos[i].deviationThreshold) {
                revert("The transaction used a wrong price");
            }
            console.log("Your current settlement price is reasonable");
        }
        return true;
    }

    function changeOwner(address newOwner) external OnlyOwner {
        owner = newOwner;
    }
}
