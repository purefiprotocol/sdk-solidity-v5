// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./utils/TestPackage.sol";
import {IPureFiVerifier} from "../src/interfaces/IPureFiVerifier.sol";
import {PureFiVerifier} from "../src/PureFiVerifier.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract PureFiVerifierTest is Test {
    using ECDSA for bytes32;

    TestPackage internal testPackage;
    PureFiVerifier internal verifier;
    address internal issuerRegistry;
    uint256 internal issuerRegistryPk;

    address internal issuer;
    uint256 internal issuerPk;


    function setUp() public {
        (issuerRegistry, issuerRegistryPk) = makeAddrAndKey("issuerRegistry");
        (issuer, issuerPk) = makeAddrAndKey("issuer");

        testPackage = new TestPackage();
        verifier = new PureFiVerifier();
        verifier.initialize(issuerRegistry);

        vm.startBroadcast(issuerRegistryPk);
        verifier.grantRole(verifier.ISSUER_ROLE(), issuer);
        vm.stopBroadcast();
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
}
