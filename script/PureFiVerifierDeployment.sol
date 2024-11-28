// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {PureFiIssuerRegistry} from "../src/PureFiIssuerRegistry.sol";
import "../src/PureFiVerifier.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract PureFiVerifierDeployment is Script {
    function run() external {
        vm.startBroadcast();

        PureFiIssuerRegistry registry = deployIssuerRegistryProxy();
        PureFiVerifier verifier = deployVerifierProxy(address(registry));
        console.log("registry ", address(registry));
        console.log("verifier ", address(verifier));

        vm.stopBroadcast();
    }

    function deployIssuerRegistryProxy() internal returns (PureFiIssuerRegistry registry) {
        PureFiIssuerRegistry implementation = new PureFiIssuerRegistry();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            msg.sender,
            abi.encodeWithSelector(PureFiIssuerRegistry(implementation).initialize.selector, msg.sender)
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
