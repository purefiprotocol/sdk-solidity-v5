// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./utils/TestPackage.sol";
import {IPackageTypes} from "./utils/interfaces/IPackageTypes.sol";
import {IPureFiVerifier} from "../src/interfaces/IPureFiVerifier.sol";
import {PureFiVerifier} from "../src/PureFiVerifier.sol";
import {PureFiDataLibrary} from "../src/libraries/PureFiDataLibrary.sol";
import {WorkaroundFunctions} from "./utils/WorkaroundFunctions.sol"; // Импорт WorkaroundFunctions
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract PureFiVerifierTest is Test {
    using ECDSA for bytes32;

    TestPackage internal testPackage;
    PureFiVerifier internal verifier;
    WorkaroundFunctions internal helperFunctions; // Добавляем инстанс WorkaroundFunctions

    // Test accounts
    address internal issuerRegistry;
    uint256 internal issuerRegistryPk;
    address internal issuer;
    uint256 internal issuerPk;
    address internal randomUser;
    uint256 internal randomUserPk;

    // Events to test
    event PureFiPackageProcessed(address indexed caller, uint256 session);
    event PureFiStorageClear(address caller, uint256 sessionId);

    function setUp() public {
        // Create test accounts
        (issuerRegistry, issuerRegistryPk) = makeAddrAndKey("issuerRegistry");
        (issuer, issuerPk) = makeAddrAndKey("issuer");
        (randomUser, randomUserPk) = makeAddrAndKey("randomUser");

        // Deploy contracts
        testPackage = new TestPackage();
        verifier = new PureFiVerifier();
        helperFunctions = new WorkaroundFunctions(); // Инициализируем WorkaroundFunctions

        // Initialize verifier and assign ISSUER_ROLE
        verifier.initialize(issuerRegistry);
        vm.startPrank(issuerRegistry);
        verifier.grantRole(verifier.ISSUER_ROLE(), issuer);
        vm.stopPrank();
    }

    /**
     * @dev Creates a valid payload with the given package type and applies custom modifications
     * @param packageType The type of package to include in the payload
     * @param timestamp Optional timestamp to use (defaults to current block.timestamp)
     * @param customFrom Optional custom "from" address for the package
     * @param customTo Optional custom "to" address for the package
     * @param customSession Optional custom session ID for the package
     * @return The encoded payload ready for verification
     */
    function createValidPayload(
        uint8 packageType,
        uint64 timestamp,
        address customFrom,
        address customTo,
        uint256 customSession
    ) internal returns (bytes memory, uint256) {
        if (timestamp == 0) {
            timestamp = uint64(block.timestamp);
        }

        bytes memory package;
        uint256 sessionId;

        if (packageType == 1) {
            IPackageTypes.PackageType1 memory pkg = testPackage.getTestPackageType1();
            if (customFrom != address(0)) pkg.from = customFrom;
            if (customTo != address(0)) pkg.to = customTo;
            if (customSession != 0) pkg.session = customSession;
            package = abi.encode(pkg);
            sessionId = pkg.session;
        } else if (packageType == 2) {
            IPackageTypes.PackageType2 memory pkg = testPackage.getTestPackageType2();
            if (customSession != 0) pkg.session = customSession;
            package = abi.encode(pkg);
            sessionId = pkg.session;
        } else if (packageType == 32) {
            IPackageTypes.PackageType32 memory pkg = testPackage.getTestPackageType32();
            if (customSession != 0) pkg.session = customSession;
            package = abi.encode(pkg);
            sessionId = pkg.session;
        } else {
            IPackageTypes.PackageType64 memory pkg = testPackage.getTestPackageType64();
            if (customFrom != address(0)) pkg.from = customFrom;
            if (customSession != 0) pkg.session = customSession;
            package = abi.encode(pkg);
            sessionId = pkg.session;
        }

        bytes32 digest = keccak256(abi.encodePacked(timestamp, package));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        return (abi.encode(timestamp, signature, package), sessionId);
    }

    /**
     * @dev Helper function to create payload with default values for optional parameters
     */
    function createValidPayload(uint8 packageType, uint64 timestamp) internal returns (bytes memory) {
        (bytes memory payload, ) = createValidPayload(packageType, timestamp, address(0), address(0), 0);
        return payload;
    }

    /**
     * @dev Helper function for address customization without session customization
     */
    function createValidPayload(uint8 packageType, uint64 timestamp, address customFrom, address customTo)
    internal returns (bytes memory)
    {
        (bytes memory payload, ) = createValidPayload(packageType, timestamp, customFrom, customTo, 0);
        return payload;
    }

    /**
     * @dev Test successfully validating a payload with package type 2
     */
    function testValidatePackageType2() public {
        bytes memory encodedPackage = createValidPayload(2, 0);

        vm.startSnapshotGas("validatePackageType2");
        vm.expectEmit(true, true, false, false);
        emit PureFiPackageProcessed(address(this), testPackage.getTestPackageType2().session);
        verifier.validatePayload(encodedPackage);
        uint256 gasUsed = vm.stopSnapshotGas();
        console.log("Gas used for validatePackageType2:", gasUsed);

        // Verify the session was stored
        assertGt(verifier.requestsProcessed(testPackage.getTestPackageType2().session), 0);
    }

    /**
     * @dev Test validating a payload with package type 0 when caller matches "from" field
     */
    function testValidatePackageType0WithMatchingCaller() public {
        // Create a package where the from field is this contract's address
        bytes memory encodedPackage = createValidPayload(0, 0, address(this), address(0));
        verifier.validatePayload(encodedPackage);

        // Verify the session was stored
        IPackageTypes.PackageType64 memory package = testPackage.getTestPackageType64();
        assertGt(verifier.requestsProcessed(package.session), 0);
    }

    /**
     * @dev Test validating a payload with package type 1 when caller matches "to" field
     */
    function testValidatePackageType1WithMatchingCaller() public {
        // Create a package where the to field is this contract's address
        bytes memory encodedPackage = createValidPayload(1, 0, address(0), address(this));
        verifier.validatePayload(encodedPackage);

        // Verify the session was stored
        IPackageTypes.PackageType1 memory package = testPackage.getTestPackageType1();
        assertGt(verifier.requestsProcessed(package.session), 0);
    }

    /**
     * @dev Test validation fails with too short payload
     */
    function testRevertWithTooShortPayload() public {
        bytes memory tooShortPayload = abi.encode(uint64(block.timestamp));

        vm.expectRevert();
        verifier.validatePayload(tooShortPayload);
    }

    /**
     * @dev Test validation fails when signature is not from an authorized issuer
     */
    function testRevertWithUnauthorizedIssuer() public {
        uint64 timestamp = uint64(block.timestamp);
        bytes memory package = abi.encode(testPackage.getTestPackageType2());
        bytes32 digest = keccak256(abi.encodePacked(timestamp, package));

        // Sign with unauthorized key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(randomUserPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory encodedPackage = abi.encode(timestamp, signature, package);

        vm.expectRevert();
        verifier.validatePayload(encodedPackage);
    }

    /**
     * @dev Test validation fails when payload has expired
     */
    function testRevertWithExpiredPayload() public {
        // First, set the current block timestamp to a reasonable value
        vm.warp(1000000);

        // Create payload with timestamp in the past
        uint64 timestamp = uint64(block.timestamp - verifier.graceTime() - 1);
        bytes memory encodedPackage = createValidPayload(2, timestamp);

        vm.expectRevert(PureFiVerifier.PureFiDataExpiredError.selector);
        verifier.validatePayload(encodedPackage);
    }

    /**
     * @dev Test validation fails when the same session ID is used twice
     */
    function testRevertWithAlreadyUsedPayload() public {
        // For package type 2, we don't need to set from/to as it's exempt from caller validation
        bytes memory encodedPackage = createValidPayload(2, 0);

        // First validation should succeed
        verifier.validatePayload(encodedPackage);

        // Second validation with same package should fail
        vm.expectRevert(PureFiVerifier.AlreadyUsedPayloadError.selector);
        verifier.validatePayload(encodedPackage);
    }

    /**
     * @dev Test validation fails when caller does not match "to" field for package types 0 and 1
     */
    function testRevertWithInvalidContractCaller() public {
        // Create a package with a "to" field that doesn't match our caller
        bytes memory encodedPackage = createValidPayload(1, 0, address(0), randomUser);

        // Try to validate from a different address
        vm.expectRevert(PureFiVerifier.InvalidContractCallerError.selector);
        verifier.validatePayload(encodedPackage);
    }

    /**
     * @dev Test the clearStorage function with expired and non-expired sessions
     */
    function testClearStorage() public {
        // Create packages with different session IDs
        uint256 session1 = 12345;
        uint256 session2 = 67890;

        (bytes memory encodedPackage1, ) = createValidPayload(2, 0, address(0), address(0), session1);
        (bytes memory encodedPackage2, ) = createValidPayload(2, 0, address(0), address(0), session2);

        verifier.validatePayload(encodedPackage1);
        verifier.validatePayload(encodedPackage2);

        // Verify sessions are stored
        assertGt(verifier.requestsProcessed(session1), 0);
        assertGt(verifier.requestsProcessed(session2), 0);

        // Move time forward more than a day
        vm.warp(block.timestamp + 86401);

        // Prepare sessions array
        uint256[] memory sessions = new uint256[](2);
        sessions[0] = session1;
        sessions[1] = session2;

        // Clear storage and check event
        vm.expectEmit(true, false, false, true);
        emit PureFiStorageClear(address(this), 2);
        verifier.clearStorage(sessions);

        // Verify sessions were cleared
        assertEq(verifier.requestsProcessed(session1), 0);
        assertEq(verifier.requestsProcessed(session2), 0);
    }

    /**
     * @dev Test that clearStorage only clears sessions older than 1 day
     */
    function testClearStorageWithNonExpiredSessions() public {
        // Create and validate a payload with custom session ID
        uint256 session = 9999;
        (bytes memory encodedPackage, ) = createValidPayload(2, 0, address(0), address(0), session);
        verifier.validatePayload(encodedPackage);

        // Verify session is stored
        assertGt(verifier.requestsProcessed(session), 0);

        // Prepare sessions array
        uint256[] memory sessions = new uint256[](1);
        sessions[0] = session;

        // Try to clear storage when session is not expired
        vm.expectEmit(true, false, false, true);
        emit PureFiStorageClear(address(this), 0);
        verifier.clearStorage(sessions);

        // Verify session was not cleared
        assertGt(verifier.requestsProcessed(session), 0);
    }

    /**
     * @dev Test the version function returns the correct value
     */
    function testVersion() public {
        assertEq(verifier.version(), 5000000);
    }

    function testValidate() public {
        uint64 time = uint64(block.timestamp);
        bytes memory package = abi.encode(testPackage.getTestPackageType2());
        bytes32 digest = keccak256(abi.encodePacked(time, package));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);

        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory encodedPackage = abi.encode(time, signature, package);

        vm.startSnapshotGas("externalA");
        verifier.validatePayload(encodedPackage);
        uint256 gasUsed = vm.stopSnapshotGas();

        console.log(gasUsed);
    }

    /**
     * @dev Test that getPackage extracts the correct package data from a full PureFi payload
     */
    function testGetPackage() public {
        // Create a valid payload with package type 2
        bytes memory encodedPackage = createValidPayload(2, 0);
        bytes memory expectedPackage = abi.encode(testPackage.getTestPackageType2());

        // Extract package using helperFunctions
        bytes memory extractedPackage = helperFunctions.workaround_getPackage(encodedPackage);

        // Verify the extracted package matches the expected package
        assertEq(keccak256(extractedPackage), keccak256(expectedPackage), "Extracted package does not match expected package");
    }

    /**
     * @dev Test that getTimestamp extracts the correct timestamp from a full PureFi payload
     */
    function testGetTimestamp() public {
        // Create a valid payload with a specific timestamp
        uint64 expectedTimestamp = uint64(block.timestamp);
        bytes memory encodedPackage = createValidPayload(2, expectedTimestamp);

        // Extract timestamp using helperFunctions
        uint64 extractedTimestamp = helperFunctions.workaround_getTimestamp(encodedPackage);

        // Verify the extracted timestamp matches the expected timestamp
        assertEq(extractedTimestamp, expectedTimestamp, "Extracted timestamp does not match expected timestamp");
    }

    /**
     * @dev Test that getSignature extracts the correct signature from a full PureFi payload
     */
    function testGetSignature() public {
        // Create a valid payload with package type 2
        uint64 timestamp = uint64(block.timestamp);
        bytes memory package = abi.encode(testPackage.getTestPackageType2());
        bytes32 digest = keccak256(abi.encodePacked(timestamp, package));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);
        bytes memory expectedSignature = abi.encodePacked(r, s, v);

        bytes memory encodedPackage = abi.encode(timestamp, expectedSignature, package);

        // Extract signature using helperFunctions
        bytes memory extractedSignature = helperFunctions.workaround_getSignature(encodedPackage);

        // Verify the extracted signature matches the expected signature
        assertEq(keccak256(extractedSignature), keccak256(expectedSignature), "Extracted signature does not match expected signature");
    }

    /**
     * @dev Test that decodePureFiData extracts all components correctly from a full PureFi payload
     */
    function testDecodePureFiData() public {
        // Create a valid payload with package type 2
        uint64 expectedTimestamp = uint64(block.timestamp);
        bytes memory package = abi.encode(testPackage.getTestPackageType2());
        bytes32 digest = keccak256(abi.encodePacked(expectedTimestamp, package));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);
        bytes memory expectedSignature = abi.encodePacked(r, s, v);
        bytes memory encodedPackage = abi.encode(expectedTimestamp, expectedSignature, package);

        // Extract components using decodePureFiData through helperFunctions
        (uint64 extractedTimestamp, bytes memory extractedSignature, bytes memory extractedPackage) =
                            helperFunctions.workaround_decodePureFiData(encodedPackage);

        // Verify all extracted components match expected values
        assertEq(extractedTimestamp, expectedTimestamp, "Timestamp does not match expected value");
        assertEq(keccak256(extractedSignature), keccak256(expectedSignature), "Signature does not match expected value");
        assertEq(keccak256(extractedPackage), keccak256(package), "Package does not match expected value");
    }
}