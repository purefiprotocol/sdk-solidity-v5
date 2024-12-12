// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

struct PureFiData {
    uint64 timestamp;
    bytes signature;
    bytes package;
}

interface IPureFiVerifier {
    /// @dev Validates a given payload and returns the parsed package data.
    /// @param payload The payload to validate.
    function validatePayload(bytes calldata payload) external;
}
