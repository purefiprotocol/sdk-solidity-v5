// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/PureFiIssuerRegistry.sol";
import "../src/PureFiVerifier.sol";

contract PureFiIssuerRegistryTest is Test {
    PureFiIssuerRegistry public registry;
    PureFiVerifier public verifier;

    address private admin = address(0xA11CE);
    address private issuer = address(0xBEEF);

    function setUp() public {
        // Deploy both contracts
        registry = new PureFiIssuerRegistry();
        verifier = new PureFiVerifier();

        // Deploy as admin
        vm.startPrank(admin);
        registry.initialize(admin);
        verifier.initialize(address(registry));
        registry.setVerifier(address(verifier));
        vm.stopPrank();
    }

    function testVersion() public {
        assertEq(registry.version(), 2000000);
    }

    function testInitializeSetsAdminRole() public {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
    }

    function testSetVerifier() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit PureFiIssuerRegistry.VerifierSettle(address(verifier));

        registry.setVerifier(address(verifier));
        assertEq(address(registry.verifier()), address(verifier));
    }

    function testRegisterIssuer() public {
        vm.startPrank(admin);
        registry.setVerifier(address(verifier));
        vm.stopPrank();

        // registry is the only address with DEFAULT_ADMIN_ROLE in verifier
        vm.prank(admin);
        registry.register(issuer);
        assertTrue(verifier.hasRole(verifier.ISSUER_ROLE(), issuer));
    }

    function testUnregisterIssuer() public {
        vm.startPrank(admin);
        registry.setVerifier(address(verifier));
        registry.register(issuer);
        registry.unregister(issuer);
        vm.stopPrank();

        assertFalse(verifier.hasRole(verifier.ISSUER_ROLE(), issuer));
    }

}
