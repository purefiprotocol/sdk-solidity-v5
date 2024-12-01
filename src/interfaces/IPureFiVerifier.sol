// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

struct PureFiData {
    uint64 timestamp;
    bytes signature;
    bytes package;
}

interface IPureFiVerifier {
    function validatePayload(bytes calldata payload) external;
}
