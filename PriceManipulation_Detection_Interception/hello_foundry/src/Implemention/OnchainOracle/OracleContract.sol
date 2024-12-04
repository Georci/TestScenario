// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./Interface/AggregatorV2V3Interface.sol";
import "./utils/Owned.sol";
import "./libraries/FixidityLib.sol";

/**
 * @notice Onchain verification of reports from the offchain reporting protocol
 * @notice 验证链上来自链下报告协议的报告
 * @dev For details on its operation, see the offchain reporting protocol design
 * @dev doc, which refers to this contract as simply the "contract".
 */
contract OffchainAggregator is Owned, AggregatorV2V3Interface {
    // Transmission records the median answer from the transmit transaction at
    // time timestamp
    struct Transmission {
        int192 answer; // 192 bits ought to be enough for anyone
        uint64 timestamp;
        address transmitter;
    }
    mapping(uint32 /* aggregator round ID */ => Transmission)
        internal s_transmissions;


    // 后期可扩展
    struct HotVars {
        uint32 latestAggregatorRoundId;
    }
    HotVars internal s_hotVars;

    // 存在当前合约中的价格默认小数位数
    uint8 public decimals = 24;

    // 比对的描述, 如 ETH / USDT
    string internal s_description;

    // current oracle contract version
    uint256 public constant override version = 1;

    // Ken:The maximum allowed difference between defaultToken's offchain price and dex price
    // example：0.5%, 5, 3
    int192 defaultToken_deviationThreshold;
    uint8 defaultToken_deviationThresholdDecimals;

    int192 otherToken_deviationThreshold;
    uint8 otherToken_deviationThresholdDecimals;

    // 我的想法是为当前的answer增加一个defaultToken，这样一来如果不是default的话，就将answer取反
    address defaultToken;
    address otherToken;

    // TODO:这里的逻辑可能还需要完善一下？比如交易对的地址是不是需要初始化？代币对的描述？
    constructor(
        string memory _description, 
        address _defaultToken,
        address _otherToken,
        int192 _defaultToken_deviationThreshold,
        uint8 _defaultToken_deviationThresholdDecimals,
        int192 _otherToken_deviationThreshold,
        uint8 _otherToken_deviationThresholdDecimals
    ) {
        s_description = _description;
        defaultToken = _defaultToken;
        otherToken = _otherToken;
        defaultToken_deviationThreshold = _defaultToken_deviationThreshold;
        defaultToken_deviationThresholdDecimals = _defaultToken_deviationThresholdDecimals;
        otherToken_deviationThreshold = _otherToken_deviationThreshold;
        otherToken_deviationThresholdDecimals = _otherToken_deviationThresholdDecimals;
    }

    function setDecimals(uint8 _decimals) external {
        decimals = _decimals;
    }

    /*
     * Versioning
     */
    function typeAndVersion() external pure virtual returns (string memory) {
        return "OffchainAggregator 1.0.0";
    }

    function latestAnswer() external view returns (int256) {
        return s_transmissions[s_hotVars.latestAggregatorRoundId].answer;
    }

    function latestTimestamp() external view returns (uint256) {
        return s_transmissions[s_hotVars.latestAggregatorRoundId].timestamp;
    }

    function getDefaultToken() external view returns (address) {
        return defaultToken;
    }

    function getOtherToken() external view returns (address) {
        return otherToken;
    }

    function latestRound() external view returns (uint256) {
        return s_hotVars.latestAggregatorRoundId;
    }

    function getAnswer(uint256 _roundId) external view returns (int256) {
        if (_roundId > 0xFFFFFFFF) {
            return 0;
        }
        return s_transmissions[uint32(_roundId)].answer;
    }

    function getTimestamp(uint256 _roundId) external view returns (uint256) {
        if (_roundId > 0xFFFFFFFF) {
            return 0;
        }
        return s_transmissions[uint32(_roundId)].timestamp;
    }

    function getDecimals() external view returns (uint8) {
        return decimals;
    }

    function description() external view returns (string memory) {
        return s_description;
    }

    function getdefaultTokenDeviationThreshold()
        external
        view
        returns (int192)
    {
        return defaultToken_deviationThreshold;
    }

    function getdefaultTokenDeviationThresholdDecimals()
        external
        view
        returns (uint8)
    {
        return defaultToken_deviationThresholdDecimals;
    }

    function getotherTokenDeviationThreshold() external view returns (int192) {
        return otherToken_deviationThreshold;
    }

    function getotherTokenDeviationThresholdDecimals()
        external
        view
        returns (uint8)
    {
        return otherToken_deviationThresholdDecimals;
    }

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        require(_roundId <= 0xFFFFFFFF, "roundId exceeds limits");
        Transmission memory transmission = s_transmissions[uint32(_roundId)];
        return (
            _roundId,
            transmission.answer,
            transmission.timestamp,
            transmission.timestamp,
            _roundId
        );
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = s_hotVars.latestAggregatorRoundId;

        Transmission memory transmission = s_transmissions[uint32(roundId)];
        return (
            roundId,
            transmission.answer,
            transmission.timestamp,
            transmission.timestamp,
            roundId
        );
    }

    /**
     * report new data process
     * todo!: 更新过程验证
     */
    /**
     * @notice indicates that a new report was transmitted
     * @param aggregatorRoundId the round to which this report was assigned
     * @param answer median of the observations attached this report
     * @param transmitter address from which the report was transmitted
     * @param observations observations transmitted with this report
     */
    event NewTransmission(
        uint32 indexed aggregatorRoundId,
        int192 answer,
        address transmitter,
        int192[] observations
    );
    struct ReportData {
        HotVars hotVars;
        int192[] observations;
    }

    function setdefaultTokenDeviationThreshold(
        int192 _defaultToken_deviationThreshold
    ) public onlyOwner {
        defaultToken_deviationThreshold = _defaultToken_deviationThreshold;
    }

    function setdefaultTokenDeviationThresholdDecimals(
        uint8 _defaultToken_deviationThresholdDecimals
    ) public {
        defaultToken_deviationThresholdDecimals = _defaultToken_deviationThresholdDecimals;
    }

    function setotherTokenDeviationThreshold(
        int192 _otherToken_deviationThreshold
    ) public onlyOwner {
        otherToken_deviationThreshold = _otherToken_deviationThreshold;
    }

    function setotherTokenDeviationThresholdDecimals(
        uint8 _otherToken_deviationThresholdDecimals
    ) public {
        otherToken_deviationThresholdDecimals = _otherToken_deviationThresholdDecimals;
    }

    /**
     * @dev 链下价格通过该函数被保存在当前合约中
     */
    function transmit(int192 _offchianPrice, uint8 _decimals) external {
        ReportData memory r;
        r.hotVars = s_hotVars;

        int192 offchianPrice = int192(
            FixidityLib.convertFixed(_offchianPrice, _decimals, decimals)
        );
        r.hotVars.latestAggregatorRoundId++;
        s_transmissions[r.hotVars.latestAggregatorRoundId] = Transmission(
            offchianPrice,
            uint64(block.timestamp),
            tx.origin
        );

        emit NewTransmission(
            r.hotVars.latestAggregatorRoundId,
            offchianPrice,
            tx.origin,
            r.observations
        );
        // Emit these for backwards compatability with offchain consumers
        // that only support legacy events
        emit NewRound(
            r.hotVars.latestAggregatorRoundId,
            address(0x0), // use zero address since we don't have anybody "starting" the round here
            block.timestamp
        );
        emit AnswerUpdated(
            offchianPrice,
            r.hotVars.latestAggregatorRoundId,
            block.timestamp
        );

        s_hotVars = r.hotVars;
    }
}
