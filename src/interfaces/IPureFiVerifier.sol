// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IPureFiVerifier {
    function validateAndDecode(bytes calldata pureFiData) external;
}