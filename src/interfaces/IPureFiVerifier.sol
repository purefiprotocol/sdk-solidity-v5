// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

struct PureFiData {
    uint64 timestamp;
    bytes signature;
    bytes package;
}

interface IPureFiVerifier {

    event PureFiPackageProcessed(address indexed caller, uint256 session);
    event PureFiStorageClear(address caller, uint256 sessionId);
    event Withdrawn(address feeCollector, uint256 amount);

    error PureFiDataExpiredError();
    error TooShortPayloadError();
    error AlreadyUsedPayloadError();
    error InvalidContractCallerError();
    error PaidPayloadNotAllowed();
    error VerificationPaymentFailed();

    /// @dev Validates a given payload and returns the parsed package data.
    /// @param payload The payload to validate.
    function validatePayload(bytes calldata payload) external;
    function withdraw(address account, uint256 amount) external;
    function paidValidatePayload(bytes calldata _payload) external payable;
    function clearStorage(uint256[] memory _sessions) external;
}
