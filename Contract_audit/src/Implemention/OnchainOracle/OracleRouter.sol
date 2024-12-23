pragma solidity ^0.8.0;

import {AggregatorV2V3Interface} from "../OnchainOracle/Interface/AggregatorV2V3Interface.sol";

contract OracleRouter {
    address owner;

    mapping(address => mapping(address => address)) tokensToOracle;

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Access not authorized");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        owner = newOwner;
    }

    function setInfo(
        address _targetToken,
        address _otherToken,
        address oracle
    ) external onlyOwner {
        address targetToken = AggregatorV2V3Interface(oracle).getDefaultToken();
        address otherToken = AggregatorV2V3Interface(oracle).getOtherToken();

        require(
            (_targetToken == targetToken && _otherToken == otherToken) ||
                (_targetToken == otherToken && _otherToken == targetToken),
            "Token addresses do not match oracle data"
        );

        tokensToOracle[_targetToken][_otherToken] = oracle;
        tokensToOracle[_otherToken][_targetToken] = oracle;
    }

    function removeInfo(
        address _targetToken,
        address _otherToken
    ) external onlyOwner {
        delete tokensToOracle[_targetToken][_otherToken];
        delete tokensToOracle[_otherToken][_targetToken];
    }

    // 私有函数：获取oracle地址
    function _getOracle(
        address _targetToken,
        address _otherToken
    ) private view returns (AggregatorV2V3Interface) {
        address oracle = tokensToOracle[_targetToken][_otherToken];
        require(oracle != address(0), "Oracle not found");
        return AggregatorV2V3Interface(oracle);
    }

    function latestAnswer(
        address _targetToken,
        address _otherToken
    ) external view returns (int256 latestAnswer) {
        latestAnswer = _getOracle(_targetToken, _otherToken).latestAnswer();
    }

    function latestTimestamp(
        address _targetToken,
        address _otherToken
    ) external view returns (uint256 latestTimestamp) {
        latestTimestamp = _getOracle(_targetToken, _otherToken)
            .latestTimestamp();
    }

    function latestRound(
        address _targetToken,
        address _otherToken
    ) external view returns (uint256 latestRound) {
        latestRound = _getOracle(_targetToken, _otherToken).latestRound();
    }

    function getAnswer(
        address _targetToken,
        address _otherToken,
        uint256 roundId
    ) external view returns (int256 answer) {
        answer = _getOracle(_targetToken, _otherToken).getAnswer(roundId);
    }

    function getTimestamp(
        address _targetToken,
        address _otherToken,
        uint256 roundId
    ) external view returns (uint256 timestamp) {
        timestamp = _getOracle(_targetToken, _otherToken).getTimestamp(roundId);
    }

    function decimals(
        address _targetToken,
        address _otherToken
    ) external view returns (uint8 decimals) {
        decimals = _getOracle(_targetToken, _otherToken).decimals();
    }

    function description(
        address _targetToken,
        address _otherToken
    ) external view returns (string memory description) {
        description = _getOracle(_targetToken, _otherToken).description();
    }

    function version(
        address _targetToken,
        address _otherToken
    ) external view returns (uint256 version) {
        version = _getOracle(_targetToken, _otherToken).version();
    }

    function getRoundData(
        address _targetToken,
        address _otherToken,
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
        (roundId, answer, startedAt, updatedAt, answeredInRound) = _getOracle(
            _targetToken,
            _otherToken
        ).getRoundData(_roundId);
    }

    function latestRoundData(
        address _targetToken,
        address _otherToken
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
        (roundId, answer, startedAt, updatedAt, answeredInRound) = _getOracle(
            _targetToken,
            _otherToken
        ).latestRoundData();
    }

    function getdefaultTokenDeviationThreshold(
        address _targetToken,
        address _otherToken
    ) external view returns (int192 deviationThresholdOffDex) {
        deviationThresholdOffDex = _getOracle(_targetToken, _otherToken)
            .getdefaultTokenDeviationThreshold();
    }

    function getdefaultTokenDeviationThresholdDecimals(
        address _targetToken,
        address _otherToken
    ) external view returns (uint8 deviationThresholdOffDexDecimals) {
        deviationThresholdOffDexDecimals = _getOracle(_targetToken, _otherToken)
            .getdefaultTokenDeviationThresholdDecimals();
    }

    function getotherTokenDeviationThreshold(
        address _targetToken,
        address _otherToken
    ) external view returns (int192 deviationThresholdOffDex) {
        deviationThresholdOffDex = _getOracle(_targetToken, _otherToken)
            .getotherTokenDeviationThreshold();
    }

    function getotherTokenDeviationThresholdDecimals(
        address _targetToken,
        address _otherToken
    ) external view returns (uint8 deviationThresholdOffDexDecimals) {
        deviationThresholdOffDexDecimals = _getOracle(_targetToken, _otherToken)
            .getotherTokenDeviationThresholdDecimals();
    }

    function getDefaultToken(
        address _targetToken,
        address _otherToken
    ) external view returns (address defaultToken) {
        defaultToken = _getOracle(_targetToken, _otherToken).getDefaultToken();
    }

    function getOtherToken(
        address _targetToken,
        address _otherToken
    ) external view returns (address otherToken) {
        otherToken = _getOracle(_targetToken, _otherToken).getOtherToken();
    }
}
