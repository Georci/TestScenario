pragma solidity ^0.8.0;
import {ProxyForRouter} from "../proxy/proxyForRouter.sol";
import "../../lib/forge-std/src/Test.sol";

contract PriceMani {
    ProxyForRouter router;

    constructor(address _routerProxy) {
        router = ProxyForRouter(payable(_routerProxy));
    }

    // 假设该函数是进行金融结算的函数
    function test_param(uint8 a) public returns (bool is_attack) {
        bytes memory data = abi.encodeWithSignature(
            "executeWithDetect(bytes)",
            msg.data
        );
        router.CallOn(data);

        if (a >= 100) {
            is_attack = true;
            console.log("Attack successful");
        }
    }

    // 如果受保护的项目使用了代理，那么请问防火墙入口是插在代理里面还是逻辑里面呢
    function test_price(bytes calldata _data) public returns (bool is_attack) {
        bytes memory data = abi.encodeWithSignature(
            "executeWithDetect(bytes)",
            msg.data
        );
        console2.logBytes(data);
        router.CallOn(data);
        console.log("wxishidsad");
        is_attack = false;
        return is_attack;
    }

    function set(uint256 a, uint256 b) public {}
}
