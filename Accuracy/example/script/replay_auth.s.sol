import {Script, console} from "forge-std/Script.sol";
import {DeployToken, DeployPair, FireWallDeployer, AttackFirst, AttackSecond} from "../src/Utils.sol";

contract CreateEnv is Script {
    FireWallDeployer firewall;

    function setUp() public {}

    function run() public {
        FireWallDeployer fd = new FireWallDeployer();
        console.log("proxy_registry", address(fd.proxy_registry()));
        console.log("auth_detect", address(fd.auth_detect()));
        console.log("registry", address(fd.registry()));
    }
}
/**
 * auth_detect 0x5e68f07f7D52B1a45B2BfDEefBbe2BC9547a846C
 *  proxy_registry 0x071b84Ad9cE5E5914264625BCc653fe3d99cdd47
 *  registry 0x7BAB0b362CacbBB3DBBa0Ca9B7DAf3735DAe8e40
 */
