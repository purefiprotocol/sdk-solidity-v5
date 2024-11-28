// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

struct PureFiData {
    uint64 timestamp;
    bytes signature;
    bytes package;
}

struct VerificationPackage {
    uint8 packageType;
    uint256 session;
    uint256 rule;
    address from;
    address to;
    address token;
    uint256 amount;
    bytes payload;
}

interface IPureFiVerifier {
    function validatePayload(bytes calldata payload) external;

    /// @notice backward compatibility
    // @Deprecated
    function validateAndDecode(bytes calldata _purefidata) external returns (VerificationPackage memory);
    // @Deprecated
    function validatePureFiData(bytes calldata _purefidata) external returns (bytes memory, uint16);
    //    // @Deprecated
    function decodePureFiPackage(bytes calldata _purefipackage) external pure returns (VerificationPackage memory);
}
