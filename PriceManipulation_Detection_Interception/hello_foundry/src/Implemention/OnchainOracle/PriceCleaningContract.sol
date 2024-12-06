// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interface/AggregatorV2V3Interface.sol";
import "../Interface/IPriceCleaningContract.sol";
import "../OnchainOracle/libraries/FixidityLib.sol";
import "../Interface/interface.sol";
import "forge-std/Test.sol";

// TODO:针对目前的价格清洗合约来说，我们并没有在“权限控制”、“性能优化”、“节约成本”以及某些“条件控制”方面做的很完善。
contract PriceCleaningContract is IPriceCleaningContract {
    using FixidityLib for *;
    // 所有价格(链上、链下)统一使用24位小数
    uint8 public constant DECIMALS = 24;

    // oracle address(每一个oracle地址代表了特定的代币对) => DexInfo
    mapping(address => DexInfo[]) public oracleToDexInfo;

    // offchainPrice from oracle contract
    mapping(address => int256) public oracleToOffchainPrice;

    address public owner;
    address public priceModule;

    event UpdateOffchainPrice(address updater, int256 updatePrice);

    event AddDexInfo(
        address _oracle,
        address updater,
        string _dexName,
        string _poolDescription,
        address pool
    );
    event UpdateDexInfo(
        address updater,
        string _dexName,
        string _poolDescription,
        address pool,
        address token
    );
    event DelDexInfo(
        address updater,
        string _dexName,
        string _poolDescription,
        address pool
    );
    event SetTokenPriceForOneDex(
        address updater,
        string _dexName,
        string _poolDescription,
        address pool,
        address token
    );
    event SetTokenPriceForAllDexs(address updater, address token);

    function initialize(address _owner) public {
        owner = _owner;
    }

    function setPriceModule(address _priceModule) external  {
        priceModule = _priceModule;
    }

    modifier OnlyOwner() {
        console.log("msg.sender:", msg.sender);
        console.log("owner:", owner);
        console.log("tx.origin:", tx.origin);
        require(
            msg.sender == owner || tx.origin == owner,
            "only owner can call this function!"
        );
        _;
    }

    // 目前，我认为PriceCleaning合约中不应该保存历史数据，而且我们只针对五个交易所中同一对代币价格进行清洗
    /**
     * @notice 添加主流交易所用于计算真实价格
     * @param _oracle 当前交易所(真是价格来源)对应的预言机合约(代币对)
     * @param _pool 当前交易所中该代币对的地址
     * @param _token 默认代币地址
     * @param _otherToken 非默认代币地址
     * @param _txAmount 该dex当前pool的交易数量(用于计算真实价格)
     */
    // TODO:这里的IUniswapV2Pair应该要做成一个普遍适用的接口，由于defi协议不同，其接口可能差异较大
    function addDexInfo(
        address _oracle,
        address _pool,
        address _token,
        address _otherToken,
        uint8 _txAmount
    ) external {
        DexInfo[] storage dexInfos = oracleToDexInfo[_oracle];
        address token0;
        address token1;

        try IUniswapV2Pair(_pool).token0() returns (address _token0) {
            token0 = _token0;
            token1 = IUniswapV2Pair(_pool).token1();
        } catch {
            try ICurvePool(_pool).coins(uint256(0)) returns (address _token0) {
                token0 = _token0;
                token1 = ICurvePool(_pool).coins(uint256(1));
            } catch {
                // Fallback to PancakeSwap interface if both Uniswap V2 Pair and ICurvePool fail
                token0 = IPancakeV3Pool(_pool).token0();
                token1 = IPancakeV3Pool(_pool).token1();
            }
        }
        require(
            _token == token0 || _token == token1,
            "This pool doesn't includes cleaningToken"
        );

        for (uint8 i = 0; i < dexInfos.length; i++) {
            require(dexInfos[i].pool != _pool, "This pool already exsit!");
        }

        // 手动增加数组长度并赋值
        dexInfos.push(
            DexInfo({
                pool: _pool,
                token: _token,
                price: 0,
                otherToken: _otherToken,
                otherPrice: 0,
                txAmount: _txAmount,
                isEnabled: true
            })
        );
    }

    /**
     * @notice 更新目标交易所信息
     * @param _oracle 预言机合约地址
     * @param index 检索的交易所在数组中的位置
     * @param _txAmount 交易所中的交易所数量
     * @param _pool 币对地址
     * @param _isEnabled 是否启用
     */
    function updateDexInfo(
        address _oracle,
        uint8 index,
        uint8 _txAmount,
        address _pool,
        bool _isEnabled
    ) external OnlyOwner {
        DexInfo[] storage dexInfos = oracleToDexInfo[_oracle];

        require(index < dexInfos.length, "index exceeds!");
        address token0;
        address token1;

        try ICurvePool(dexInfos[index].pool).coins(uint256(0)) returns (
            address _token0
        ) {
            token0 = _token0;
            token1 = ICurvePool(dexInfos[index].pool).coins(uint256(1));
        } catch {
            // Fallback to Uniswap V2 Pair if ICurvePool.coins fails
            token0 = IUniswapV2Pair(dexInfos[index].pool).token0();
            token1 = IUniswapV2Pair(dexInfos[index].pool).token1();
        }
        require(
            dexInfos[index].token == token0 || dexInfos[index].token == token1,
            "This pool doesn't includes cleaningToken"
        );

        dexInfos[index].txAmount = _txAmount;
        dexInfos[index].pool = _pool;
        dexInfos[index].isEnabled = _isEnabled;
    }

    /**
     * @notice 删除某个代币对对应的交易所信息
     * @param _oracle 预言机合约
     * @param index 要删除的交易所在数组中的位置
     */
    function delDexInfoForOnePair(
        address _oracle,
        uint8 index
    ) external OnlyOwner {
        DexInfo[] storage dexInfos = oracleToDexInfo[_oracle];

        require(index < dexInfos.length, "index exceeds!");

        dexInfos[index] = dexInfos[dexInfos.length - 1];
        dexInfos.pop();
    }

    /**
     * @notice 删除一个代币对对应的全部交易所信息
     * @param _oracle 预言机合约
     */
    function delDexInfoForAllDexs(address _oracle) external OnlyOwner {
        delete oracleToDexInfo[_oracle];
    }

    /**
     * @notice 该函数用于为一个代币对的所有交易所更新其单个代币价格
     * @param _oracle 预言机合约
     * @param _needToken 需要更新价格的代币
     */
    function setTokenPriceForAllDexs(
        address _oracle,
        address _needToken
    ) internal {
        DexInfo[] storage dexInfos = oracleToDexInfo[_oracle];
        uint dexslength = dexInfos.length;

        if (dexslength == 0) return;

        bool reverse = (_needToken == dexInfos[0].otherToken);

        for (uint8 i = 0; i < dexslength; i++) {
            address targetPool = dexInfos[i].pool;
            address targetToken = dexInfos[i].token;
            address token0;
            address token1;

            try ICurvePool(targetPool).coins(uint256(0)) returns (
                address _token0
            ) {
                token0 = _token0;
                token1 = ICurvePool(targetPool).coins(uint256(1));
            } catch {
                // Fallback to Uniswap V2 Pair if ICurvePool.coins fails
                token0 = IUniswapV2Pair(targetPool).token0();
                token1 = IUniswapV2Pair(targetPool).token1();
            }

            uint token0_balance = IERC20(token0).balanceOf(targetPool);
            uint token1_balance = IERC20(token1).balanceOf(targetPool);

            console.log("token0:", token0);
            console.log("token0_balance:", token0_balance);
            console.log("token1:", token1);
            console.log("token1_balance:", token1_balance);
            int256 price = calculatePrice(
                targetToken,
                normalizeBalance(token0_balance, IERC20(token0).decimals()),
                normalizeBalance(token1_balance, IERC20(token1).decimals()),
                token0,
                token1
            );

            if (reverse) {
                dexInfos[i].otherPrice = FixidityLib.reciprocal(price);
            } else {
                dexInfos[i].price = price;
            }
        }

        emit SetTokenPriceForAllDexs(msg.sender, dexInfos[0].token);
    }

    /**
     * @notice 获取当前交易所数组中指定位置的交易所信息
     * @param index 查找的交易所信息位于当前数组中的位置
     */
    function getDexInfo(
        address _oracle,
        uint8 index
    ) external view returns (DexInfo memory dexInfo) {
        DexInfo[] storage dexInfos = oracleToDexInfo[_oracle];

        require(index < dexInfos.length, "index exceeds limit!");

        dexInfo = dexInfos[index];
        return dexInfo;
    }

    /**
     * @notice 为某代币对对应的单个交易所更新指定代币价格
     * @param _oracle 预言机合约地址
     * @param _needToken 需要更新价格的代币
     * @param index 需要更新价格的交易所在数组中的位置
     */
    function setTokenPriceForOneDex(
        address _oracle,
        address _needToken,
        uint8 index
    ) public OnlyOwner {
        DexInfo storage dexInfo = oracleToDexInfo[_oracle][index];

        address token0;
        address token1;

        try ICurvePool(dexInfo.pool).coins(uint256(0)) returns (
            address _token0
        ) {
            token0 = _token0;
            token1 = ICurvePool(dexInfo.pool).coins(uint256(1));
        } catch {
            // Fallback to Uniswap V2 Pair if ICurvePool.coins fails
            token0 = IUniswapV2Pair(dexInfo.pool).token0();
            token1 = IUniswapV2Pair(dexInfo.pool).token1();
        }

        uint token0_balance = IERC20(token0).balanceOf(dexInfo.pool);
        uint token1_balance = IERC20(token1).balanceOf(dexInfo.pool);

        int256 price = calculatePrice(
            dexInfo.token,
            normalizeBalance(token0_balance, IERC20(token0).decimals()),
            normalizeBalance(token1_balance, IERC20(token1).decimals()),
            token0,
            token1
        );
        if (dexInfo.token == _needToken) {
            dexInfo.price = price;
        } else {
            dexInfo.otherPrice = FixidityLib.reciprocal(price);
        }
    }

    /**
     * @notice 辅助函数，用来帮助calculatePrice函数
     * @param balance 代币余额
     * @param decimals 代币余额的小数位数
     */
    function normalizeBalance(
        uint balance,
        uint8 decimals
    ) public pure returns (int256) {
        return FixidityLib.convertFixed(int256(balance), decimals, DECIMALS);
    }

    /**
     * @notice 计算两种代币价格(代币数量已经完成精度转换)
     * @param targetToken 计算价格的目标代币
     * @param normalized_token0_balance token0的余额
     * @param normalized_token1_balance token1的余额
     * @param token0 代币0
     * @param token1 代币1
     */
    function calculatePrice(
        address targetToken,
        int256 normalized_token0_balance,
        int256 normalized_token1_balance,
        address token0,
        address token1
    ) public pure returns (int256) {
        if (targetToken == token0) {
            return
                FixidityLib.divide(
                    normalized_token1_balance,
                    normalized_token0_balance
                );
        } else if (targetToken == token1) {
            return
                FixidityLib.divide(
                    normalized_token0_balance,
                    normalized_token1_balance
                );
        } else {
            revert("Requested token is not part of the pair");
        }
    }

    /**
     * @notice 获取链下价格
     * @param _oracle 链上预言机合约
     * @param _needToken 需要获取价格的代币
     */
    // TODO:我觉得这个地方不应该是OnlyOWner
    function updateOffchainPrice(address _oracle, address _needToken) internal {
        // Fetch all required data in a single call where possible
        (, int256 answer, , , ) = AggregatorV2V3Interface(_oracle)
            .latestRoundData();
        uint8 decimals = AggregatorV2V3Interface(_oracle).decimals();
        address defaultToken = AggregatorV2V3Interface(_oracle)
            .getDefaultToken();

        require(answer >= 0, "Answer is negative");

        // Use a local variable for calculations to minimize storage accesses
        int256 fixedAnswer = answer;

        // Adjust the price only if the decimals are different and necessary
        if (decimals != DECIMALS) {
            fixedAnswer = FixidityLib.convertFixed(answer, decimals, DECIMALS);
        }

        // Update the price based on the token match
        if (_needToken == defaultToken) {
            oracleToOffchainPrice[_oracle] = fixedAnswer;
        } else {
            oracleToOffchainPrice[_oracle] = FixidityLib.reciprocal(
                fixedAnswer
            );
        }

        // Logging for debugging (can be removed in production to save gas)
        console.log("defaultToken:", defaultToken);
        console.log("_needtoken:", _needToken);
        console.log("latestOffchianPrice is :", uint256(fixedAnswer));

        emit UpdateOffchainPrice(msg.sender, fixedAnswer);
    }

    /**
     * @notice 清洗交易所中的价格，剔除掉不可信的代币价格
     * @param _oracle 进行价格清洗的链下价格来源合约地址，此处会被用来获取当前链下价格与传入的交易所价格的最大差值
     */
    function cleanDexPrice(address _oracle, address _needToken) internal {
        DexInfo[] storage dexInfos = oracleToDexInfo[_oracle];
        int256 price;
        bool reverse;
        for (uint8 i = 0; i < dexInfos.length; i++) {
            if (_needToken == dexInfos[i].token) {
                price = dexInfos[i].price;
            } else {
                price = dexInfos[i].otherPrice;
                reverse = true;
            }
            console2.log(dexInfos[i].price);

            bool _isEnable = compareOffchainpriceWithFixedPrice(
                price,
                _oracle,
                reverse
            );
            console.log("isEnable :", _isEnable);

            dexInfos[i].isEnabled = _isEnable;
        }
    }

    /**
     * @notice 比较传入的链上价格与当前合约保存的链下价格，若二者差距大于deviationThreshold，则return false
     * @param onchainPrice 链上价格，使用int256(int64.int192)的形式保存
     * @param _oracle 进行价格清洗的链下价格来源合约地址，此处会被用来获取当前链下价格与传入的交易所价格的最大差值
     */
    function compareOffchainpriceWithFixedPrice(
        int256 onchainPrice,
        address _oracle,
        bool reverse
    ) internal view returns (bool) {
        int256 offchainPrice = oracleToOffchainPrice[_oracle];
        require(offchainPrice != 0, "You need to upload offchian price first");

        console.log("offchainPrice is :", uint256(offchainPrice));
        console.log("onchainPrice is :", uint256(onchainPrice));
        // 链上价格与链下价格在decimals被修正到一样的时候，可以直接使用加减进行比较了
        int256 priceDifference = FixidityLib.abs(onchainPrice - offchainPrice);
        priceDifference = FixidityLib.divide(priceDifference, offchainPrice);

        console.log("priceDifference :", uint256(priceDifference));

        // 比较
        int192 deviationThreshold;
        uint8 deviationThresholdDecimals;
        if (!reverse) {
            deviationThreshold = AggregatorV2V3Interface(_oracle)
                .getdefaultTokenDeviationThreshold();
            deviationThresholdDecimals = AggregatorV2V3Interface(_oracle)
                .getdefaultTokenDeviationThresholdDecimals();
        } else {
            deviationThreshold = AggregatorV2V3Interface(_oracle)
                .getotherTokenDeviationThreshold();
            deviationThresholdDecimals = AggregatorV2V3Interface(_oracle)
                .getotherTokenDeviationThresholdDecimals();
        }

        require(
            deviationThreshold != 0,
            "You need to set deviationThreshold first"
        );
        int256 deviationThresholdFixed = FixidityLib.convertFixed(
            deviationThreshold,
            deviationThresholdDecimals,
            DECIMALS
        );
        if (priceDifference > deviationThresholdFixed) {
            return false;
        }
        return true;
    }

    // TODO:具体来说要需要获取几个交易所在当前以太坊浏览器中的交易占比，利用个交易所的交易占比乘以其交易所提供的价格计算真实价格
    /**
     * @notice 计算真实价格
     */
    function calculateRealPrice(
        address _oracle,
        address _needToken
    ) public view returns (int256 realPrice) {
        DexInfo[] memory dexInfos = oracleToDexInfo[_oracle];
        uint8 usableDexCount = 0;
        uint16 txTotal = 0;
        int256 weightedPriceSum = 0;
        bool reserve;

        for (uint8 i = 0; i < dexInfos.length; i++) {
            // 只考虑启用了的交易所
            reserve = (dexInfos[i].otherToken == _needToken);
            if (dexInfos[i].isEnabled == true) {
                usableDexCount += 1;
                if (!reserve) {
                    txTotal += dexInfos[i].txAmount;
                    weightedPriceSum +=
                        dexInfos[i].price *
                        int8(dexInfos[i].txAmount);
                } else {
                    txTotal += dexInfos[i].txAmount;
                    weightedPriceSum +=
                        dexInfos[i].otherPrice *
                        int8(dexInfos[i].txAmount);
                }
            }
        }

        int256 txTotal_fixed = FixidityLib.newFixed(int256(int16(txTotal)));
        // 只有当启用的交易所数量大于一个，且存在交易时，真实价格才会使用链上价格计算
        if (txTotal > 0 && usableDexCount > 1) {
            realPrice = FixidityLib.divide(weightedPriceSum, txTotal_fixed);
        } else {
            realPrice = oracleToOffchainPrice[_oracle];
        }
        // realPrice默认具有24位小数
        return realPrice;
    }

    /**
     * @notice 该函数整合了计算真实价格的全部流程，仅能为防火墙priceModule提供真实价格
     * @param _oracle 预言机合约
     * @param _needToken 需要计算真实价格的代币
     */
    function getRealPriceByModule(
        address _oracle,
        address _needToken
    ) external returns (int256 realPrice) {
        require(msg.sender == priceModule, "Unauthorized call");

        setTokenPriceForAllDexs(_oracle, _needToken);
        updateOffchainPrice(_oracle, _needToken);
        cleanDexPrice(_oracle, _needToken);

        realPrice = calculateRealPrice(_oracle, _needToken);
    }

    /**
     * @notice 该函数可以为任意地址提供给真实价格
     * @param _oracle 预言机合约
     */
    function getRealPrice(
        address _oracle,
        address _needToken
    ) external returns (int256 realPrice) {
        realPrice = calculateRealPrice(_oracle, _needToken);
    }

    function changeOwner(address newOwner) external OnlyOwner {
        owner = newOwner;
    }
}
