// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./utils/TestPackage.sol";
import {IPackageTypes} from "./utils/interfaces/IPackageTypes.sol";
import {IPureFiVerifier} from "../src/interfaces/IPureFiVerifier.sol";
import {PureFiVerifier} from "../src/PureFiVerifier.sol";
import {PureFiDataLibrary} from "../src/libraries/PureFiDataLibrary.sol";
import {WorkaroundFunctions} from "./utils/WorkaroundFunctions.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract PureFiVerifierTest is Test {
    using ECDSA for bytes32;

    TestPackage internal testPackage;
    PureFiVerifier internal verifier;
    WorkaroundFunctions internal helperFunctions;

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
    event Withdrawn(address feeCollector, uint256 amount);

    /**
     * @dev Sets up the initial state for all tests.
     * Generates cryptographic key pairs for testing accounts, deploys the required
     * smart contracts, initializes the PureFiVerifier, and assigns the necessary
     * ISSUER_ROLE to the test issuer address.
     */
    function setUp() public {
        (issuerRegistry, issuerRegistryPk) = makeAddrAndKey("issuerRegistry");
        (issuer, issuerPk) = makeAddrAndKey("issuer");
        (randomUser, randomUserPk) = makeAddrAndKey("randomUser");

        testPackage = new TestPackage();
        verifier = new PureFiVerifier();
        helperFunctions = new WorkaroundFunctions();

        verifier.initialize(issuerRegistry);
        vm.startPrank(issuerRegistry);
        verifier.grantRole(verifier.ISSUER_ROLE(), issuer);
        vm.stopPrank();
    }

    /**
     * @dev Creates a valid payload with the given package type and applies custom modifications.
     * This is a core helper function used across tests to simulate backend signature generation.
     */
    function createValidPayload(
        uint8 packageType,
        uint64 timestamp,
        address customFrom,
        address customTo,
        uint256 customSession
    ) internal view returns (bytes memory, uint256) {
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
     * @dev Overloaded helper function to create payload with default values for optional parameters.
     */
    function createValidPayload(uint8 packageType, uint64 timestamp) internal view returns (bytes memory) {
        (bytes memory payload,) = createValidPayload(packageType, timestamp, address(0), address(0), 0);
        return payload;
    }

    /**
     * @dev Overloaded helper function for address customization without session customization.
     */
    function createValidPayload(uint8 packageType, uint64 timestamp, address customFrom, address customTo)
        internal
        view
        returns (bytes memory)
    {
        (bytes memory payload,) = createValidPayload(packageType, timestamp, customFrom, customTo, 0);
        return payload;
    }

    /**
     * @dev Tests the successful validation of a Type 2 package.
     * Expects the 'PureFiPackageProcessed' event to be emitted and verifies
     * that the session ID was correctly stored in the contract's state to prevent replay attacks.
     */
    function testValidatePackageType2() public {
        bytes memory encodedPackage = createValidPayload(2, 0);

        vm.startSnapshotGas("validatePackageType2");
        vm.expectEmit(true, true, false, false);
        emit PureFiPackageProcessed(address(this), testPackage.getTestPackageType2().session);
        verifier.validatePayload(encodedPackage);
        uint256 gasUsed = vm.stopSnapshotGas();
        console.log("Gas used for validatePackageType2:", gasUsed);

        assertGt(verifier.requestsProcessed(testPackage.getTestPackageType2().session), 0);
    }

    /**
     * @dev Tests the validation of a Type 1 package where the caller matches the "from" address.
     * Ensures that address binding restrictions work correctly.
     */
    function testValidatePackageType0WithMatchingCaller() public {
        bytes memory encodedPackage = createValidPayload(1, 0, address(this), address(0));
        verifier.validatePayload(encodedPackage);

        IPackageTypes.PackageType1 memory package = testPackage.getTestPackageType1();
        assertGt(verifier.requestsProcessed(package.session), 0);
    }

    /**
     * @dev Tests the validation of a Type 1 package where the caller matches the "to" address.
     * Ensures that address binding restrictions allow the intended recipient to process the payload.
     */
    function testValidatePackageType1WithMatchingCaller() public {
        bytes memory encodedPackage = createValidPayload(1, 0, address(0), address(this));
        verifier.validatePayload(encodedPackage);

        IPackageTypes.PackageType1 memory package = testPackage.getTestPackageType1();
        assertGt(verifier.requestsProcessed(package.session), 0);
    }

    /**
     * @dev Ensures that the contract reverts if the provided payload byte array is shorter
     * than the absolute minimum required length (timestamp + signature + minimal package).
     */
    function testRevertWithTooShortPayload() public {
        bytes memory tooShortPayload = abi.encode(uint64(block.timestamp));

        vm.expectRevert();
        verifier.validatePayload(tooShortPayload);
    }

    /**
     * @dev Ensures the contract reverts if the payload was signed by an address
     * that does NOT have the ISSUER_ROLE. Simulates a malicious actor trying to fake a verification.
     */
    function testRevertWithUnauthorizedIssuer() public {
        uint64 timestamp = uint64(block.timestamp);
        bytes memory package = abi.encode(testPackage.getTestPackageType2());
        bytes32 digest = keccak256(abi.encodePacked(timestamp, package));

        // Sign with a random user key instead of the official issuer key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(randomUserPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory encodedPackage = abi.encode(timestamp, signature, package);

        vm.expectRevert();
        verifier.validatePayload(encodedPackage);
    }

    /**
     * @dev Ensures the contract reverts if the payload timestamp is older than the allowed grace time.
     * Simulates a delayed transaction or an attacker trying to use an old payload.
     */
    function testRevertWithExpiredPayload() public {
        vm.warp(1000000); // Fast forward time to avoid underflow

        // Create a timestamp just outside the grace time window
        uint64 timestamp = uint64(block.timestamp - verifier.graceTime() - 1);
        bytes memory encodedPackage = createValidPayload(2, timestamp);

        vm.expectRevert(IPureFiVerifier.PureFiDataExpiredError.selector);
        verifier.validatePayload(encodedPackage);
    }

    /**
     * @dev Tests the contract's defense against Replay Attacks.
     * A valid payload is processed successfully the first time, but a second attempt
     * with the exact same payload must revert.
     */
    function testRevertWithAlreadyUsedPayload() public {
        bytes memory encodedPackage = createValidPayload(2, 0);

        verifier.validatePayload(encodedPackage); // First try: Success

        vm.expectRevert(IPureFiVerifier.AlreadyUsedPayloadError.selector);
        verifier.validatePayload(encodedPackage); // Second try: Revert
    }

    /**
     * @dev Ensures the contract reverts if the caller does not match either the "to" or "from"
     * fields specified within the payload, preventing unauthorized execution by third parties.
     */
    function testRevertWithInvalidContractCaller() public {
        // Specify that randomUser is the expected "to" address
        bytes memory encodedPackage = createValidPayload(1, 0, address(0), randomUser);

        // This contract (address(this)) tries to execute it instead of randomUser
        vm.expectRevert(IPureFiVerifier.InvalidContractCallerError.selector);
        verifier.validatePayload(encodedPackage);
    }

    /**
     * @dev Tests the manual garbage collection function.
     * Validates that stored session IDs are successfully deleted from the state
     * if they are older than 1 day.
     */
    function testClearStorage() public {
        uint256 session1 = 12345;
        uint256 session2 = 67890;

        (bytes memory encodedPackage1,) = createValidPayload(2, 0, address(0), address(0), session1);
        (bytes memory encodedPackage2,) = createValidPayload(2, 0, address(0), address(0), session2);

        verifier.validatePayload(encodedPackage1);
        verifier.validatePayload(encodedPackage2);

        assertGt(verifier.requestsProcessed(session1), 0);
        assertGt(verifier.requestsProcessed(session2), 0);

        // Move time forward more than a day (86400 seconds)
        vm.warp(block.timestamp + 86401);

        uint256[] memory sessions = new uint256[](2);
        sessions[0] = session1;
        sessions[1] = session2;

        vm.expectEmit(true, false, false, true);
        emit PureFiStorageClear(address(this), 2); // Expect 2 cleared sessions
        verifier.clearStorage(sessions);

        // Verify sessions were deleted (values reset to 0)
        assertEq(verifier.requestsProcessed(session1), 0);
        assertEq(verifier.requestsProcessed(session2), 0);
    }

    /**
     * @dev Ensures that the garbage collection function does NOT delete sessions
     * that are still within the 1-day retention period.
     */
    function testClearStorageWithNonExpiredSessions() public {
        uint256 session = 9999;
        (bytes memory encodedPackage,) = createValidPayload(2, 0, address(0), address(0), session);
        verifier.validatePayload(encodedPackage);

        uint256[] memory sessions = new uint256[](1);
        sessions[0] = session;

        vm.expectEmit(true, false, false, true);
        emit PureFiStorageClear(address(this), 0); // Expect 0 cleared sessions
        verifier.clearStorage(sessions);

        // Verify session remains intact
        assertGt(verifier.requestsProcessed(session), 0);
    }

    /**
     * @dev Verifies that the version getter returns the correctly hardcoded version integer.
     */
    function testVersion() public view {
        assertEq(verifier.version(), 5014000);
    }

    /**
     * @dev A general validation test tracking gas consumption for a barebones payload execution.
     */
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
     * @dev Ensures that a payload containing payment data (Type 64) is explicitly rejected
     * when submitted through the free 'validatePayload' function instead of 'paidValidatePayload'.
     */
    function testPaidPayloadNotAllowed() public {
        uint64 time = uint64(block.timestamp);
        TestPackage.PackageType64 memory testPaidPackage = testPackage.getTestPackageType64();

        bytes memory package = abi.encode(testPaidPackage);
        bytes32 digest = keccak256(abi.encodePacked(time, package));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory encodedPackage = abi.encode(time, signature, package);

        vm.expectRevert("PaidPayloadNotAllowed()");
        verifier.validatePayload(encodedPackage);
    }

    /**
     * @dev Another payload length check using raw hex data to simulate a corrupted or incomplete packet.
     */
    function testTooShortPayload() public {
        vm.expectRevert("TooShortPayloadError()");
        bytes memory encodedPackage = abi.encode(hex"11111111");
        verifier.validatePayload(encodedPackage);
    }

    /**
     * @dev Tests the happy path for verifying a paid payload using the Native Token (ETH/BNB).
     * Ensures the transaction succeeds when sufficient native currency is attached.
     */
    function testPaidValidatePayload() public {
        address tokenAddress = address(0); // Indicates Native Token
        uint256 amount = 100000;
        uint64 time = uint64(block.timestamp);

        TestPackage.PackageType64 memory testPaidPackage = testPackage.getTestPackageType64();
        testPaidPackage.paymentData = (uint256(uint160(tokenAddress)) << 96) | uint256(amount);
        testPaidPackage.from = randomUser;

        bytes memory package = abi.encode(testPaidPackage);
        bytes32 digest = keccak256(abi.encodePacked(time, package));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory encodedPackage = abi.encode(time, signature, package);

        vm.deal(randomUser, 100 ether); // Provide test user with ETH
        vm.broadcast(randomUserPk);
        verifier.paidValidatePayload{value: amount}(encodedPackage); // Send plenty of ETH to cover the amount
    }

    /**
     * @dev Tests the happy path for verifying a paid payload using an ERC20 token.
     * Mints mock tokens, approves the verifier, and processes the payload successfully.
     */
    function testERC20PaidValidatePayload() public {
        ERC20Mock mockToken = new ERC20Mock();
        mockToken.mint(randomUser, 1e26);

        address tokenAddress = address(mockToken);
        uint256 amount = 100000 * 1e17;
        uint64 time = uint64(block.timestamp);

        TestPackage.PackageType64 memory testPaidPackage = testPackage.getTestPackageType64();
        testPaidPackage.paymentData = (uint256(uint160(tokenAddress)) << 96) | uint256(amount);
        testPaidPackage.from = randomUser;

        bytes memory package = abi.encode(testPaidPackage);
        bytes32 digest = keccak256(abi.encodePacked(time, package));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory encodedPackage = abi.encode(time, signature, package);

        vm.deal(randomUser, 100 ether);

        vm.broadcast(randomUserPk);
        mockToken.approve(address(verifier), amount); // Approve ERC20 spending

        vm.broadcast(randomUserPk);
        verifier.paidValidatePayload(encodedPackage); // Call without msg.value
    }

    /**
     * @dev Ensures the contract reverts if the user attempts to pay for an ERC20-priced
     * verification by attaching native currency (`msg.value`) alongside the transaction.
     */
    function testERC20PaymentError() public {
        ERC20Mock mockToken = new ERC20Mock();
        mockToken.mint(randomUser, 1e26);

        address tokenAddress = address(mockToken);
        uint256 amount = 100000 * 1e17;
        uint64 time = uint64(block.timestamp);

        TestPackage.PackageType64 memory testPaidPackage = testPackage.getTestPackageType64();
        testPaidPackage.paymentData = (uint256(uint160(tokenAddress)) << 96) | uint256(amount);
        testPaidPackage.from = randomUser;

        bytes memory package = abi.encode(testPaidPackage);
        bytes32 digest = keccak256(abi.encodePacked(time, package));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory encodedPackage = abi.encode(time, signature, package);

        vm.deal(randomUser, 100 ether);

        vm.broadcast(randomUserPk);
        mockToken.approve(address(verifier), amount);

        vm.broadcast(randomUserPk);
        vm.expectRevert("ERC20PaymentError()");
        // Calling an ERC20 payload while attaching native ETH
        verifier.paidValidatePayload{value: 1 ether}(encodedPackage);
    }

    /**
     * @dev Tests the data library's ability to extract the inner package bytes
     * from the fully concatenated payload block.
     */
    function testGetPackage() public view {
        bytes memory encodedPackage = createValidPayload(2, 0);
        bytes memory expectedPackage = abi.encode(testPackage.getTestPackageType2());

        bytes memory extractedPackage = helperFunctions.workaround_getPackage(encodedPackage);

        assertEq(
            keccak256(extractedPackage), keccak256(expectedPackage), "Extracted package does not match expected package"
        );
    }

    /**
     * @dev Tests the data library's ability to extract the timestamp (first 8 bytes)
     * from the concatenated payload block.
     */
    function testGetTimestamp() public view {
        uint64 expectedTimestamp = uint64(block.timestamp);
        bytes memory encodedPackage = createValidPayload(2, expectedTimestamp);

        uint64 extractedTimestamp = helperFunctions.workaround_getTimestamp(encodedPackage);

        assertEq(extractedTimestamp, expectedTimestamp, "Extracted timestamp does not match expected timestamp");
    }

    /**
     * @dev Tests the data library's ability to extract the ECDSA signature
     * from the concatenated payload block.
     */
    function testGetSignature() public view {
        uint64 timestamp = uint64(block.timestamp);
        bytes memory package = abi.encode(testPackage.getTestPackageType2());
        bytes32 digest = keccak256(abi.encodePacked(timestamp, package));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);
        bytes memory expectedSignature = abi.encodePacked(r, s, v);

        bytes memory encodedPackage = abi.encode(timestamp, expectedSignature, package);

        bytes memory extractedSignature = helperFunctions.workaround_getSignature(encodedPackage);

        assertEq(
            keccak256(extractedSignature),
            keccak256(expectedSignature),
            "Extracted signature does not match expected signature"
        );
    }

    /**
     * @dev Tests the main data library decoding function, ensuring timestamp, signature,
     * and inner package are correctly separated in a single call.
     */
    function testDecodePureFiData() public view {
        uint64 expectedTimestamp = uint64(block.timestamp);
        bytes memory package = abi.encode(testPackage.getTestPackageType2());
        bytes32 digest = keccak256(abi.encodePacked(expectedTimestamp, package));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);
        bytes memory expectedSignature = abi.encodePacked(r, s, v);
        bytes memory encodedPackage = abi.encode(expectedTimestamp, expectedSignature, package);

        (uint64 extractedTimestamp, bytes memory extractedSignature, bytes memory extractedPackage) =
            helperFunctions.workaround_decodePureFiData(encodedPackage);

        assertEq(extractedTimestamp, expectedTimestamp, "Timestamp does not match expected value");
        assertEq(keccak256(extractedSignature), keccak256(expectedSignature), "Signature does not match expected value");
        assertEq(keccak256(extractedPackage), keccak256(package), "Package does not match expected value");
    }

    /**
     * @dev Tests the native token withdrawal function when a fee collector withdraws
     * the entire contract balance to their own address.
     */
    function testWithdrawSuccessCollectorWithdrawsAll() public {
        address feeCollector = makeAddr("feeCollector");
        vm.startPrank(issuerRegistry);
        verifier.grantRole(verifier.FEE_COLLECTOR_ROLE(), feeCollector);
        vm.stopPrank();

        uint256 withdrawAmount = 1 ether;
        uint256 initialContractBalance = withdrawAmount;
        vm.deal(address(verifier), initialContractBalance);

        uint256 initialCollectorBalance = feeCollector.balance;

        vm.startPrank(feeCollector);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(feeCollector, withdrawAmount);
        verifier.withdraw(feeCollector, withdrawAmount);
        vm.stopPrank();

        assertEq(feeCollector.balance, initialCollectorBalance + withdrawAmount);
        assertEq(address(verifier).balance, 0);
    }

    /**
     * @dev Tests the native token withdrawal function when a fee collector withdraws
     * only a portion of the contract balance to their own address.
     */
    function testWithdrawSuccessCollectorWithdrawsPartial() public {
        address feeCollector = makeAddr("feeCollector");
        vm.startPrank(issuerRegistry);
        verifier.grantRole(verifier.FEE_COLLECTOR_ROLE(), feeCollector);
        vm.stopPrank();

        uint256 contractBalance = 2 ether;
        uint256 withdrawAmount = 1 ether;
        vm.deal(address(verifier), contractBalance);

        uint256 initialCollectorBalance = feeCollector.balance;

        vm.startPrank(feeCollector);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(feeCollector, withdrawAmount);
        verifier.withdraw(feeCollector, withdrawAmount);
        vm.stopPrank();

        assertEq(feeCollector.balance, initialCollectorBalance + withdrawAmount);
        assertEq(address(verifier).balance, contractBalance - withdrawAmount);
    }

    /**
     * @dev Tests withdrawing native tokens to an authorized recipient. The recipient has the
     * role, but the caller pays the gas (this reflects the crank pattern architecture).
     */
    function testWithdrawSuccessCollectorWithdrawsToAnotherCollector() public {
        address feeCollector = makeAddr("feeCollector");
        address anotherCollector = makeAddr("anotherCollector");

        vm.startPrank(issuerRegistry);
        verifier.grantRole(verifier.FEE_COLLECTOR_ROLE(), feeCollector);
        verifier.grantRole(verifier.FEE_COLLECTOR_ROLE(), anotherCollector);
        vm.stopPrank();

        uint256 withdrawAmount = 1 ether;
        vm.deal(address(verifier), withdrawAmount);

        uint256 initialAnotherCollectorBalance = anotherCollector.balance;
        uint256 initialCollectorBalance = feeCollector.balance;

        vm.startPrank(feeCollector);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(anotherCollector, withdrawAmount);
        verifier.withdraw(anotherCollector, withdrawAmount);
        vm.stopPrank();

        assertEq(anotherCollector.balance, initialAnotherCollectorBalance + withdrawAmount);
        assertEq(feeCollector.balance, initialCollectorBalance);
        assertEq(address(verifier).balance, 0);
    }

    /**
     * @dev Ensures the withdrawal reverts if the specified recipient address
     * lacks the required FEE_COLLECTOR_ROLE (Access Control failure).
     */
    function testWithdrawRevertWithdrawerNoRole() public {
        address nonCollector = makeAddr("nonCollector");

        uint256 withdrawAmount = 1 ether;
        vm.deal(address(verifier), withdrawAmount);

        // Try to withdraw to an account without the role
        vm.startPrank(nonCollector);
        vm.expectRevert();
        verifier.withdraw(nonCollector, withdrawAmount);
        vm.stopPrank();

        assertEq(address(verifier).balance, withdrawAmount);
    }

    /**
     * @dev Verifies that withdrawal reverts if the target destination address
     * does not have the FEE_COLLECTOR_ROLE, even if the caller does.
     */
    function testWithdrawRevertReceiverNoRole() public {
        address feeCollector = makeAddr("feeCollector");
        address nonCollector = makeAddr("nonCollector");

        vm.startPrank(issuerRegistry);
        verifier.grantRole(verifier.FEE_COLLECTOR_ROLE(), feeCollector);
        vm.stopPrank();

        uint256 withdrawAmount = 1 ether;
        vm.deal(address(verifier), withdrawAmount);

        vm.startPrank(feeCollector);
        vm.expectRevert();
        verifier.withdraw(nonCollector, withdrawAmount);
        vm.stopPrank();

        assertEq(address(verifier).balance, withdrawAmount);
    }

    /**
     * @dev Tests that attempting a withdrawal of 0 native tokens succeeds but
     * obviously alters no balances.
     */
    function testWithdrawRevertAmountZero() public {
        address feeCollector = makeAddr("feeCollector");
        vm.startPrank(issuerRegistry);
        verifier.grantRole(verifier.FEE_COLLECTOR_ROLE(), feeCollector);
        vm.stopPrank();

        vm.deal(address(verifier), 1 ether);

        vm.startPrank(feeCollector);
        verifier.withdraw(feeCollector, 0);
        vm.stopPrank();

        assertEq(address(verifier).balance, 1 ether);
    }

    /**
     * @dev Ensures the withdrawal reverts gracefully with a 'WithdrawFailed' error
     * if attempting to withdraw more native tokens than the contract currently holds.
     */
    function testWithdrawRevertAmountExceedsBalance() public {
        address feeCollector = makeAddr("feeCollector");
        vm.startPrank(issuerRegistry);
        verifier.grantRole(verifier.FEE_COLLECTOR_ROLE(), feeCollector);
        vm.stopPrank();

        uint256 contractBalance = 0.5 ether;
        uint256 withdrawAmount = 1 ether;
        vm.deal(address(verifier), contractBalance);

        vm.startPrank(feeCollector);
        vm.expectRevert("WithdrawFailed()");
        verifier.withdraw(feeCollector, withdrawAmount);
        vm.stopPrank();

        assertEq(address(verifier).balance, contractBalance);
    }

    /**
     * @dev Ensures the proxy initialization function reverts if passing the zero address
     * to prevent accidental lockouts of the default admin.
     */
    function testReinitialize() public {
        vm.expectRevert("InvalidInitialization()");
        verifier.initialize(address(0));
    }

    // =============================================================
    // NEW TESTS: PAYMENT AND WITHDRAWAL EDGE CASES
    // =============================================================

    /**
     * @dev Validates that the verification reverts if a user attempts to pay
     * less native currency (ETH) than required by the payload logic.
     */
    function testPaidValidatePayloadInsufficientFunds() public {
        address tokenAddress = address(0);
        uint256 amount = 100000;
        uint64 time = uint64(block.timestamp);

        TestPackage.PackageType64 memory testPaidPackage = testPackage.getTestPackageType64();
        testPaidPackage.paymentData = (uint256(uint160(tokenAddress)) << 96) | uint256(amount);
        testPaidPackage.from = randomUser;

        bytes memory package = abi.encode(testPaidPackage);
        bytes32 digest = keccak256(abi.encodePacked(time, package));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory encodedPackage = abi.encode(time, signature, package);

        vm.deal(randomUser, 100 ether);

        vm.startPrank(randomUser);
        // Expect failure because sent value (amount - 1) is less than required value
        vm.expectRevert(IPureFiVerifier.VerificationPaymentFailed.selector);
        verifier.paidValidatePayload{value: amount - 1}(encodedPackage);
        vm.stopPrank();
    }

    /**
     * @dev Tests the 'Crank' design pattern. Ensures any unauthorized user can pay the gas
     * to trigger a withdrawal of accumulated fees, provided the destination address is
     * strictly an authorized fee collector.
     */
    function testAnyCallerCanWithdrawToFeeCollector() public {
        address feeCollector = makeAddr("feeCollector");
        vm.startPrank(issuerRegistry);
        verifier.grantRole(verifier.FEE_COLLECTOR_ROLE(), feeCollector);
        vm.stopPrank();

        uint256 withdrawAmount = 1 ether;
        vm.deal(address(verifier), withdrawAmount);

        uint256 initialCollectorBalance = feeCollector.balance;

        // randomUser (no roles) initiates withdrawal targeting the authorized collector
        vm.startPrank(randomUser);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(feeCollector, withdrawAmount);
        verifier.withdraw(feeCollector, withdrawAmount);
        vm.stopPrank();

        assertEq(feeCollector.balance, initialCollectorBalance + withdrawAmount);
        assertEq(address(verifier).balance, 0);
    }

    /**
     * @dev Tests the happy path for withdrawing ERC20 tokens utilizing the Crank pattern.
     * Tokens must successfully transfer from the contract to the authorized fee collector.
     */
    function testWithdrawERC20Success() public {
        ERC20Mock mockToken = new ERC20Mock();
        address feeCollector = makeAddr("feeCollector");

        vm.startPrank(issuerRegistry);
        verifier.grantRole(verifier.FEE_COLLECTOR_ROLE(), feeCollector);
        vm.stopPrank();

        // Simulate accumulated ERC20 fees on the contract
        uint256 amount = 5000 * 1e18;
        mockToken.mint(address(verifier), amount);

        // randomUser pays the transaction gas to flush funds to the feeCollector
        vm.startPrank(randomUser);
        verifier.withdrawERC20(address(mockToken), feeCollector, amount);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(feeCollector), amount);
        assertEq(mockToken.balanceOf(address(verifier)), 0);
    }

    /**
     * @dev Verifies that attempting to withdraw ERC20 tokens to an unauthorized address
     * reverts, preventing unauthorized actors from draining the contract funds.
     */
    function testWithdrawERC20RevertReceiverNoRole() public {
        ERC20Mock mockToken = new ERC20Mock();
        address nonCollector = makeAddr("nonCollector");

        uint256 amount = 5000 * 1e18;
        mockToken.mint(address(verifier), amount);

        vm.startPrank(randomUser);
        // Expecting an AccessControl revert because nonCollector doesn't have the role
        vm.expectRevert();
        verifier.withdrawERC20(address(mockToken), nonCollector, amount);
        vm.stopPrank();

        // Ensure funds were not moved
        assertEq(mockToken.balanceOf(nonCollector), 0);
        assertEq(mockToken.balanceOf(address(verifier)), amount);
    }
}
