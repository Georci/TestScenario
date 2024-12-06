// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 导入 OpenZeppelin 的 ERC20 标准实现和访问控制模块
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";

/**
 * @title RegulatedToken
 * @dev 基于 ERC20 的代币合约，集成多种动态监管功能。
 */
contract RegulatedToken is ERC20, AccessControl, Pausable {
    // 定义角色
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // 黑名单映射，记录被限制的地址
    mapping(address => bool) private _blacklist;

    // 白名单映射，记录被允许的地址
    mapping(address => bool) private _whitelist;

    // 白名单计数器
    uint256 private _whitelistCount;

    // 单笔转账限额
    uint256 public maxTxAmount;

    // 每日转账限额
    uint256 public dailyTxLimit;
    mapping(address => uint256) private _dailyTxAmount;
    mapping(address => uint256) private _lastTxDay;

    // 模块启用标志
    bool public blacklistEnabled;
    bool public transferLimitsEnabled;

    // 事件
    event Blacklisted(address indexed account);
    event UnBlacklisted(address indexed account);
    event Whitelisted(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event MaxTxAmountUpdated(uint256 newMaxTxAmount);
    event DailyTxLimitUpdated(uint256 newDailyTxLimit);
    event BlacklistEnabled();
    event BlacklistDisabled();
    event TransferLimitsEnabled();
    event TransferLimitsDisabled();
    event WhitelistEnabled();
    event WhitelistDisabled();

    /**
     * @dev 构造函数，初始化代币名称、符号和初始供应量。
     *      同时设置角色和初始监管参数。
     * @param name_ 代币名称
     * @param symbol_ 代币符号
     * @param initialSupply 初始供应量（以最小单位计，如 18 位小数）
     * @param _maxTxAmount 单笔转账限额
     * @param _dailyTxLimit 每日转账限额
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        uint256 _maxTxAmount,
        uint256 _dailyTxLimit
    ) ERC20(name_, symbol_) {
        // 设置角色
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(REGULATOR_ROLE, msg.sender);

        // 铸造初始供应量
        _mint(msg.sender, initialSupply);

        // 设置初始转账限额
        maxTxAmount = _maxTxAmount;
        dailyTxLimit = _dailyTxLimit;

        // 初始化模块为禁用状态
        blacklistEnabled = false;
        transferLimitsEnabled = false;
    }

    /**
     * @dev 添加地址到黑名单。只有监管员可以调用。
     * @param account 要添加到黑名单的地址
     */
    function addToBlacklist(address account) external onlyRole(REGULATOR_ROLE) {
        require(!_blacklist[account], "RegulatedToken: Address is already blacklisted");
        _blacklist[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @dev 从黑名单移除地址。只有监管员可以调用。
     * @param account 要从黑名单移除的地址
     */
    function removeFromBlacklist(address account) external onlyRole(REGULATOR_ROLE) {
        require(_blacklist[account], "RegulatedToken: Address is not blacklisted");
        _blacklist[account] = false;
        emit UnBlacklisted(account);
    }

    /**
     * @dev 添加地址到白名单。只有监管员可以调用。
     * @param account 要添加到白名单的地址
     */
    function addToWhitelist(address account) external onlyRole(REGULATOR_ROLE) {
        require(!_whitelist[account], "RegulatedToken: Address is already whitelisted");
        _whitelist[account] = true;
        _whitelistCount += 1;
        emit Whitelisted(account);
    }

    /**
     * @dev 从白名单移除地址。只有监管员可以调用。
     * @param account 要从白名单移除的地址
     */
    function removeFromWhitelist(address account) external onlyRole(REGULATOR_ROLE) {
        require(_whitelist[account], "RegulatedToken: Address is not whitelisted");
        _whitelist[account] = false;
        _whitelistCount -= 1;
        emit RemovedFromWhitelist(account);
    }

    /**
     * @dev 更新单笔转账限额。只有监管员可以调用。
     * @param newMaxTxAmount 新的单笔转账限额
     */
    function updateMaxTxAmount(uint256 newMaxTxAmount) external onlyRole(REGULATOR_ROLE) {
        maxTxAmount = newMaxTxAmount;
        emit MaxTxAmountUpdated(newMaxTxAmount);
    }

    /**
     * @dev 更新每日转账限额。只有监管员可以调用。
     * @param newDailyTxLimit 新的每日转账限额
     */
    function updateDailyTxLimit(uint256 newDailyTxLimit) external onlyRole(REGULATOR_ROLE) {
        dailyTxLimit = newDailyTxLimit;
        emit DailyTxLimitUpdated(newDailyTxLimit);
    }

    /**
     * @dev 启用黑名单功能。只有监管员可以调用。
     */
    function enableBlacklist() external onlyRole(REGULATOR_ROLE) {
        require(!blacklistEnabled, "RegulatedToken: Blacklist already enabled");
        blacklistEnabled = true;
        emit BlacklistEnabled();
    }

    /**
     * @dev 禁用黑名单功能。只有监管员可以调用。
     */
    function disableBlacklist() external onlyRole(REGULATOR_ROLE) {
        require(blacklistEnabled, "RegulatedToken: Blacklist already disabled");
        blacklistEnabled = false;
        emit BlacklistDisabled();
    }

    /**
     * @dev 启用转账限额功能。只有监管员可以调用。
     */
    function enableTransferLimits() external onlyRole(REGULATOR_ROLE) {
        require(!transferLimitsEnabled, "RegulatedToken: Transfer limits already enabled");
        transferLimitsEnabled = true;
        emit TransferLimitsEnabled();
    }

    /**
     * @dev 禁用转账限额功能。只有监管员可以调用。
     */
    function disableTransferLimits() external onlyRole(REGULATOR_ROLE) {
        require(transferLimitsEnabled, "RegulatedToken: Transfer limits already disabled");
        transferLimitsEnabled = false;
        emit TransferLimitsDisabled();
    }

    /**
     * @dev 启用白名单功能。只有监管员可以调用。
     */
    function enableWhitelist() external onlyRole(REGULATOR_ROLE) {
        require(!whitelistEnabled, "RegulatedToken: Whitelist already enabled");
        whitelistEnabled = true;
        emit WhitelistEnabled();
    }

    /**
     * @dev 禁用白名单功能。只有监管员可以调用。
     */
    function disableWhitelist() external onlyRole(REGULATOR_ROLE) {
        require(whitelistEnabled, "RegulatedToken: Whitelist already disabled");
        whitelistEnabled = false;
        emit WhitelistDisabled();
    }

    bool public whitelistEnabled;

    /**
     * @dev 检查地址是否在黑名单中。
     * @param account 要检查的地址
     * @return 是否被黑名单限制
     */
    function isBlacklisted(address account) external view returns (bool) {
        return _blacklist[account];
    }

    /**
     * @dev 检查地址是否在白名单中。
     * @param account 要检查的地址
     * @return 是否在白名单中
     */
    function isWhitelisted(address account) external view returns (bool) {
        return _whitelist[account];
    }

    /**
     * @dev 覆盖 ERC20 的 _beforeTokenTransfer 函数，添加多种监管检查。
     * @param from 发送者地址
     * @param to 接收者地址
     * @param amount 转移数量
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);

        // 检查黑名单
        if (blacklistEnabled) {
            if (from != address(0)) {
                // 非铸造操作
                require(!_blacklist[from], "RegulatedToken: Sender is blacklisted");
            }
            if (to != address(0)) {
                // 非销毁操作
                require(!_blacklist[to], "RegulatedToken: Recipient is blacklisted");
            }
        }

        // 检查白名单
        if (whitelistEnabled) {
            require(_whitelist[from] || _whitelist[to], "RegulatedToken: Both sender and recipient are not whitelisted");
        }

        // 检查单笔转账限额
        if (transferLimitsEnabled && maxTxAmount > 0) {
            require(amount <= maxTxAmount, "RegulatedToken: Transfer amount exceeds the maxTxAmount");
        }

        // 检查每日转账限额
        if (transferLimitsEnabled && dailyTxLimit > 0) {
            uint256 currentDay = block.timestamp / 1 days;
            if (_lastTxDay[from] < currentDay) {
                _dailyTxAmount[from] = 0;
                _lastTxDay[from] = currentDay;
            }
            require(
                _dailyTxAmount[from] + amount <= dailyTxLimit,
                "RegulatedToken: Transfer amount exceeds the dailyTxLimit"
            );
            _dailyTxAmount[from] += amount;
        }
    }

    /**
     * @dev 暂停合约。只有管理员可以调用。
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev 恢复合约。只有管理员可以调用。
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
