pragma solidity ^0.8.0;
import {Test, console} from "../lib/forge-std/src/Test.sol";

contract Source {
    function getPrice() public view returns (address, uint256, bytes memory) {
        return (msg.sender, 100, bytes("0x01"));
    }
}

contract PriceSourceRegistry is Test {
    // 存储每个项目返回值的数据结构描述
    mapping(address => string) public dataDescriptions;
    Source source;

    function test_setUp() public {
        source = new Source();

        // 注册
        registerDataDescription(address(source), "(address, uint256)");

        //编码
        bytes memory selector = abi.encode(source.getPrice.selector);

        uint256 price = getPriceFromSource(address(source), selector, 1);
        console.log("price is :", price);
    }

    // 注册数据描述
    function registerDataDescription(
        address project,
        string memory description
    ) public {
        dataDescriptions[project] = description;
    }

    // 获取价格的通用函数
    function getPriceFromSource(
        address project,
        bytes memory data,
        uint8 priceIndex
    ) public returns (uint256 price) {
        (bool success, bytes memory returndata) = project.call(data);
        require(success, "call has failed");

        // 检查返回数据长度是否足够
        require(
            returndata.length >= (priceIndex + 1) * 32,
            "Invalid priceIndex"
        );

        // 提取对应的32字节数据
        uint256 offset = priceIndex * 32;
        bytes32 extractedData;
        assembly {
            extractedData := mload(add(returndata, add(32, offset)))
        }

        price = uint256(extractedData);
        return price;
    }
}
