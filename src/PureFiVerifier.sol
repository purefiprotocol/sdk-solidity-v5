// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "./interfaces/IPureFiVerifier.sol";
import "./libraries/CustomRevert.sol";
import {PureFiDataLibrary} from "./libraries/PureFiDataLibrary.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";

contract PureFiVerifier is AccessControlUpgradeable, IPureFiVerifier, ReentrancyGuardTransientUpgradeable {
    using CustomRevert for bytes4;
    using PureFiDataLibrary for bytes;

    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant FEE_COLLECTOR_ROLE = keccak256("FEE_COLLECTOR_ROLE");

    mapping(uint256 => uint256) public requestsProcessed;
    uint256 public graceTime;

    receive() external payable {

    }

    function initialize(address issuerRegistry) external initializer {
        // @notice 10 min * 60 seconds = 600 seconds
        // @notice block.timestamp in seconds, so we need to operate with seconds
        graceTime = 10 * 60;

        __AccessControl_init_unchained();
        _grantRole(DEFAULT_ADMIN_ROLE, issuerRegistry);
    }

    /// @dev Clears expired sessions from storage.
    /// After day
    /// @param _sessions An array of session IDs to be cleared.
    function clearStorage(uint256[] memory _sessions) external nonReentrant {
        // 86400 seconds == 1 day
        uint256 sessionCleared = 0;
        for (uint256 i = 0; i < _sessions.length; i++) {
            if (requestsProcessed[_sessions[i]] + 86400 < block.timestamp) {
                delete requestsProcessed[_sessions[i]];
                sessionCleared++;
            }
        }
        emit PureFiStorageClear(_msgSender(), sessionCleared);
    }

    /// @dev Validates a payload and marks the session as processed.
    ///
    /// Reverts with appropriate errors if the payload is invalid or the session has already been processed.
    ///
    /// @param _payload The payload to validate.
    function validatePayload(bytes calldata _payload) external nonReentrant {
        (address token, uint256 amount) = (_payload.getPackage()).getPaymentData();
        if (token != address(0) || amount != 0) {
            PaidPayloadNotAllowed.selector.revertWith();
        }

        _validatePayload(_payload);
    }

    function paidValidatePayload(bytes calldata _payload) external payable nonReentrant {
        (address token, uint256 amount) = (_payload.getPackage()).getPaymentData();

        if (amount != 0) {
            if (token != address(0)) {
                IERC20(token).transferFrom(_msgSender(), address(this), amount);
            } else {
                (bool success, ) = payable(address(this)).call{value: msg.value}("");

                if (!success) {
                    VerificationPaymentFailed.selector.revertWith();
                }
            }
        }

        _validatePayload(_payload);
    }

    /// @dev Returns the current version of the contract.
    ///
    /// @return The version number in the format `Major.minor.internal`.
    function version() public pure returns (uint32) {
        // 000.000.000 - Major.minor.internal
        return 5012000;
    }

    /// @dev Validates a payload and returns the parsed package data.
    ///
    /// @param _payload The payload to validate.
    /// @return The parsed package data.
    function _validatePayload(bytes calldata _payload) internal returns (bytes calldata) {
        //min package size = 8+65 +1+32
        if (_payload.length <= (8 + 65 + 1 + 32)) {
            TooShortPayloadError.selector.revertWith();
        }
        (uint64 timestamp, bytes calldata signature, bytes calldata package) = _payload.decodePureFiData();

        (address recovered,,) = ECDSA.tryRecover(keccak256(abi.encodePacked(timestamp, package)), signature);
        _checkRole(ISSUER_ROLE, recovered);

        if (block.timestamp > timestamp + graceTime) {
            PureFiDataExpiredError.selector.revertWith();
        }

        if (requestsProcessed[package.getSession()] != 0) {
            AlreadyUsedPayloadError.selector.revertWith();
        }

        if (
            package.getTo() != msg.sender && package.getPackageType() != 2 && package.getPackageType() != 3
            && package.getFrom() != _msgSender()
        ) {
            InvalidContractCallerError.selector.revertWith();
        }

        // @notice store requestID to avoid replay
        requestsProcessed[package.getSession()] = block.timestamp;
        emit PureFiPackageProcessed(_msgSender(), package.getSession());

        return package;
    }

    function withdraw(address account, uint256 amount) external nonReentrant {
        _checkRole(FEE_COLLECTOR_ROLE, _msgSender());
        _checkRole(FEE_COLLECTOR_ROLE, account);
        require(amount > 0, 'nothing to withdraw');
        uint256 balance = address(this).balance;
        require(balance >= amount, 'insufficient balance');

        (bool success, ) = payable(account).call{value: amount}("");
        require(success, "withdraw failed");
        emit Withdrawn(account, amount);
    }
}
