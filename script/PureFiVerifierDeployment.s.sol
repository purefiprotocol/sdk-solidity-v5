// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import {PureFiIssuerRegistry} from "../src/PureFiIssuerRegistry.sol";
import "../src/PureFiVerifier.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract PureFiVerifierDeployment is Script {
    function run() external {
        vm.startBroadcast();

        PureFiIssuerRegistry registry = deployIssuerRegistryProxy(msg.sender);
        PureFiVerifier verifier = deployVerifierProxy(address(registry));
        console.log("registry ", address(registry));
        console.log("verifier ", address(verifier));

        registry.setVerifier(address(verifier));
        //PureFi Stage Issuer
        registry.register(0x592157ab4c6FADc849fA23dFB5e2615459D1E4e5);

        vm.stopBroadcast();
    }

    function deployIssuerRegistryProxy(address admin) internal returns (PureFiIssuerRegistry registry) {
        PureFiIssuerRegistry implementation = new PureFiIssuerRegistry();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            msg.sender,
            abi.encodeWithSelector(PureFiIssuerRegistry(implementation).initialize.selector, admin)
        );

        registry = PureFiIssuerRegistry(address(proxy));
    }

    function deployVerifierProxy(address registry) internal returns (PureFiVerifier verifierProxyContract) {
        PureFiVerifier implementation = new PureFiVerifier();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            msg.sender,
            abi.encodeWithSelector(PureFiVerifier(implementation).initialize.selector, registry)
        );

        verifierProxyContract = PureFiVerifier(address(proxy));
    }
}
