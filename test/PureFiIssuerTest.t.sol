// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/PureFiIssuerRegistry.sol";
import "../src/PureFiVerifier.sol";

/**
 * @title PureFiIssuerRegistryTest
 * @dev Comprehensive test suite for the PureFiIssuerRegistry smart contract.
 * It covers initialization, access control, event emissions, and integration
 * with the PureFiVerifier contract.
 */
contract PureFiIssuerRegistryTest is Test {
    PureFiIssuerRegistry public registry;
    PureFiVerifier public verifier;

    // Test accounts
    address private admin = address(0xA11CE);
    address private issuer = address(0xBEEF);
    address private randomUser = address(0xDEAD);

    // Events explicitly redefined here to allow vm.expectEmit testing
    event IssuerAdded(address indexed issuer);
    event IssuerRemoved(address indexed issuer);
    event VerifierSettle(address indexed verifier);

    /**
     * @dev Sets up the testing environment before each test runs.
     * Deploys both the Registry and Verifier contracts, initializes them
     * with the admin address, and binds the Verifier to the Registry.
     */
    function setUp() public {
        registry = new PureFiIssuerRegistry();
        verifier = new PureFiVerifier();

        // Simulate transactions coming from the 'admin' account
        vm.startPrank(admin);

        // Initialize the registry and grant the admin the DEFAULT_ADMIN_ROLE
        registry.initialize(admin);

        // Initialize the verifier, passing the registry address so it acts as the verifier's admin
        verifier.initialize(address(registry));

        // Bind the verifier contract to the registry
        registry.setVerifier(address(verifier));

        vm.stopPrank();
    }

    /**
     * @dev Ensures the version() function returns the expected hardcoded value.
     */
    function testVersion() public view {
        assertEq(registry.version(), 5014000, "Version should match 5014000");
    }

    /**
     * @dev Verifies that the initialization process correctly assigned
     * the DEFAULT_ADMIN_ROLE to the specified admin address.
     */
    function testInitializeSetsAdminRole() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin), "Admin should have DEFAULT_ADMIN_ROLE");
    }

    /**
     * @dev Tests the successful update of the Verifier contract address.
     * It ensures the state is updated correctly and the corresponding event is emitted.
     */
    function testSetVerifier() public {
        // Deploy a mock "new" verifier to test the update logic
        PureFiVerifier newVerifier = new PureFiVerifier();

        vm.startPrank(admin);

        // We expect the VerifierSettle event to be emitted with the new address
        vm.expectEmit(true, false, false, true);
        emit VerifierSettle(address(newVerifier));

        registry.setVerifier(address(newVerifier));
        vm.stopPrank();

        // Validate that the state variable 'verifier' now points to the new contract
        assertEq(address(registry.verifier()), address(newVerifier), "Verifier address should be updated in state");
    }

    // =============================================================
    // HAPPY PATHS: ISSUER MANAGEMENT (REGISTER / UNREGISTER)
    // =============================================================

    /**
     * @dev Tests the successful registration of a new issuer.
     * Checks if the event is emitted and if the Verifier contract correctly
     * reflects the newly granted ISSUER_ROLE.
     */
    function testRegisterIssuer() public {
        vm.startPrank(admin);

        // Expect the IssuerAdded event to be emitted
        vm.expectEmit(true, false, false, true);
        emit IssuerAdded(issuer);

        registry.register(issuer);
        vm.stopPrank();

        // The issuer should now possess the ISSUER_ROLE inside the Verifier contract
        assertTrue(verifier.hasRole(verifier.ISSUER_ROLE(), issuer), "Issuer should have ISSUER_ROLE in Verifier");
    }

    /**
     * @dev Tests the successful removal of an existing issuer.
     * Registers an issuer first, then unregisters it, verifying the state change and event.
     */
    function testUnregisterIssuer() public {
        vm.startPrank(admin);

        // Step 1: Register the issuer successfully
        registry.register(issuer);
        assertTrue(verifier.hasRole(verifier.ISSUER_ROLE(), issuer));

        // Step 2: Unregister the issuer and expect the IssuerRemoved event
        vm.expectEmit(true, false, false, true);
        emit IssuerRemoved(issuer);

        registry.unregister(issuer);
        vm.stopPrank();

        // The issuer should no longer possess the ISSUER_ROLE inside the Verifier contract
        assertFalse(verifier.hasRole(verifier.ISSUER_ROLE(), issuer), "Issuer role should be revoked in Verifier");
    }

    // =============================================================
    // HAPPY PATHS: CUSTOM ROLE MANAGEMENT
    // =============================================================

    /**
     * @dev Tests the proxy function that allows the Registry admin to grant
     * ANY custom role inside the Verifier contract. This ensures 100% LCOV coverage.
     */
    function testVerifierGrantRole() public {
        bytes32 customRole = keccak256("CUSTOM_ROLE");

        vm.prank(admin);
        registry.verifierGrantRole(issuer, customRole);

        // Verify the role was successfully assigned in the Verifier contract
        assertTrue(verifier.hasRole(customRole, issuer), "Custom role should be granted in Verifier");
    }

    /**
     * @dev Tests the proxy function that allows the Registry admin to revoke
     * ANY custom role inside the Verifier contract.
     */
    function testVerifierRevokeRole() public {
        bytes32 customRole = keccak256("CUSTOM_ROLE");

        vm.startPrank(admin);
        // Grant the role first
        registry.verifierGrantRole(issuer, customRole);

        // Then revoke it
        registry.verifierRevokeRole(issuer, customRole);
        vm.stopPrank();

        // Verify the role was successfully removed
        assertFalse(verifier.hasRole(customRole, issuer), "Custom role should be revoked in Verifier");
    }

    // =============================================================
    // NEGATIVE TESTS: ACCESS CONTROL (ONLY ADMIN)
    // =============================================================

    /**
     * @dev Ensures that an unauthorized user cannot register a new issuer.
     * The transaction must revert due to OpenZeppelin's AccessControl restrictions.
     */
    function testRevertRegisterNotAdmin() public {
        vm.prank(randomUser); // Simulate transaction from an account without roles

        // Expect a revert (AccessControlUnauthorizedAccount)
        vm.expectRevert();
        registry.register(issuer);
    }

    /**
     * @dev Ensures that an unauthorized user cannot unregister an existing issuer.
     */
    function testRevertUnregisterNotAdmin() public {
        vm.prank(randomUser);

        vm.expectRevert();
        registry.unregister(issuer);
    }

    /**
     * @dev Ensures that an unauthorized user cannot change the bound Verifier address.
     */
    function testRevertSetVerifierNotAdmin() public {
        vm.prank(randomUser);

        vm.expectRevert();
        registry.setVerifier(address(verifier));
    }

    /**
     * @dev Ensures that an unauthorized user cannot grant custom roles in the Verifier via the Registry.
     */
    function testRevertVerifierGrantRoleNotAdmin() public {
        bytes32 customRole = keccak256("CUSTOM_ROLE");

        vm.prank(randomUser);

        vm.expectRevert();
        registry.verifierGrantRole(issuer, customRole);
    }

    /**
     * @dev Ensures that an unauthorized user cannot revoke custom roles in the Verifier via the Registry.
     */
    function testRevertVerifierRevokeRoleNotAdmin() public {
        bytes32 customRole = keccak256("CUSTOM_ROLE");

        vm.prank(randomUser);

        vm.expectRevert();
        registry.verifierRevokeRole(issuer, customRole);
    }
}
