// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "./interfaces/IPureFiVerifier.sol";
import "./libraries/CustomRevert.sol";
import {PureFiDataLibrary} from "./libraries/PureFiDataLibrary.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";

/**
 * @title PureFiVerifier
 * @notice Core contract for verifying cryptographic payloads issued by the PureFi ecosystem.
 * @dev Inherits from OpenZeppelin's `AccessControlUpgradeable` for role management and
 * `ReentrancyGuardTransientUpgradeable` (EIP-1153) for gas-efficient reentrancy protection.
 * It parses byte-encoded packages, verifies ECDSA signatures, enforces expiration times,
 * prevents replay attacks, and handles optional verification fees (in Native or ERC20 tokens).
 */
contract PureFiVerifier is AccessControlUpgradeable, IPureFiVerifier, ReentrancyGuardTransientUpgradeable {
    using CustomRevert for bytes4;
    using PureFiDataLibrary for bytes;

    // =============================================================
    // CONSTANTS & STATE VARIABLES
    // =============================================================

    /**
     * @notice The identifier for the role required to sign valid PureFi payloads.
     * @dev Payloads signed by addresses without this role will be rejected.
     */
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    /**
     * @notice The identifier for the role required to receive collected verification fees.
     * @dev Withdrawals can only be directed to accounts holding this role.
     */
    bytes32 public constant FEE_COLLECTOR_ROLE = keccak256("FEE_COLLECTOR_ROLE");

    /**
     * @notice Tracks processed session IDs to prevent Replay Attacks.
     * @dev Maps a unique session ID (uint256) to the block timestamp (uint256) when it was processed.
     */
    mapping(uint256 => uint256) public requestsProcessed;

    /**
     * @notice The maximum allowed time (in seconds) after a payload's timestamp that it remains valid.
     * @dev Used to prevent old, potentially compromised payloads from being executed indefinitely.
     */
    uint256 public graceTime;

    // =============================================================
    // INITIALIZATION & FALLBACK
    // =============================================================

    /**
     * @notice Allows the contract to receive native currency (e.g., ETH, BNB) directly.
     * @dev Primarily used to collect fees during `paidValidatePayload` or direct funding.
     */
    receive() external payable {}

    /**
     * @notice Initializes the upgradeable contract, setting up initial parameters and roles.
     * @dev Replaces the constructor for the proxy pattern. Can only be called once.
     * @param issuerRegistry The address of the registry contract that will hold the `DEFAULT_ADMIN_ROLE` to manage other roles.
     */
    function initialize(address issuerRegistry) external initializer {
        // @notice 10 min * 60 seconds = 600 seconds
        // @notice block.timestamp is in seconds, so we operate strictly in seconds
        graceTime = 10 * 60;

        __AccessControl_init_unchained();
        _grantRole(DEFAULT_ADMIN_ROLE, issuerRegistry);
    }

    // =============================================================
    // EXTERNAL FUNCTIONS (VERIFICATION & STORAGE)
    // =============================================================

    /**
     * @notice Clears expired sessions from the `requestsProcessed` mapping to free up state storage.
     * @dev A session is considered expired and clearable if 1 day (86400 seconds) has passed since it was processed.
     * This acts as a manual garbage collection mechanism, potentially refunding gas to the caller.
     * @param _sessions An array of specific session IDs to evaluate and clear.
     */
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

    /**
     * @notice Validates a standard (free) PureFi payload and marks the session as processed.
     * @dev Protects against Reentrancy. Reads the package type and ensures no payment is required.
     * Reverts with `PaidPayloadNotAllowed` if the package type bitmask indicates payment data (bit 64) is present.
     * @param _payload The raw byte array containing the timestamp, signature, and package.
     */
    function validatePayload(bytes calldata _payload) external nonReentrant {
        _checkPayloadLength(_payload);

        // Check if the 6th bit (64) is set, indicating a paid package
        if ((_payload.getPackage()).getPackageType() & 64 == 64) {
            (address token, uint256 amount) = (_payload.getPackage()).getPaymentData();
            // If payment data exists, this free endpoint cannot be used
            if (token != address(0) || amount != 0) {
                PaidPayloadNotAllowed.selector.revertWith();
            }
        }

        _validatePayload(_payload);
    }

    /**
     * @notice Validates a PureFi payload that requires an explicit fee payment (Native or ERC20).
     * @dev Protects against Reentrancy. Parses payment data from the payload.
     * If the required token is `address(0)`, it checks that `msg.value` covers the amount.
     * If an ERC20 token is specified, it pulls the tokens from the caller via `transferFrom`.
     * @param _payload The raw byte array containing the timestamp, signature, package, and payment requirements.
     */
    function paidValidatePayload(bytes calldata _payload) external payable nonReentrant {
        _checkPayloadLength(_payload);
        (address token, uint256 amount) = (_payload.getPackage()).getPaymentData();

        if (amount != 0) {
            if (token != address(0)) {
                // If paying with ERC20, providing msg.value (native token) is an error
                if (msg.value != 0) {
                    ERC20PaymentError.selector.revertWith();
                }
                IERC20(token).transferFrom(_msgSender(), address(this), amount);
            } else {
                // If paying with Native token, verify sufficient msg.value was sent
                if (msg.value != amount) {
                    VerificationPaymentFailed.selector.revertWith();
                }
            }
        }

        _validatePayload(_payload);
    }

    /**
     * @notice Returns the current version of the verifier contract.
     * @dev Used by external systems to verify they are interacting with the expected logic.
     * @return The version number in a flattened `MajorMinorInternal` format (e.g., 5015000).
     */
    function version() public pure returns (uint32) {
        // 000.000.000 - Major.minor.internal
        return 5014000;
    }

    // =============================================================
    // INTERNAL FUNCTIONS (CORE LOGIC)
    // =============================================================

    /**
     * @notice Internal core logic to validate the payload's integrity, signature, expiration, and routing.
     * @dev Extracts components, validates ECDSA signature against the `ISSUER_ROLE`, checks grace time,
     * ensures the session hasn't been used, and validates that the caller matches the specified `to` or `from` address
     * (unless the package type is 2 or 3, which bypass caller checks).
     * @param _payload The raw byte array to decode and validate.
     * @return The extracted inner package bytes.
     */
    function _validatePayload(bytes calldata _payload) internal returns (bytes calldata) {
        (uint64 timestamp, bytes calldata signature, bytes calldata package) = _payload.decodePureFiData();

        // Reconstruct the signed message hash and recover the signer address
        (address recovered,,) = ECDSA.tryRecover(keccak256(abi.encodePacked(timestamp, package)), signature);

        // Ensure the signer is an authorized PureFi Issuer
        _checkRole(ISSUER_ROLE, recovered);

        // Check for payload expiration
        if (block.timestamp > timestamp + graceTime) {
            PureFiDataExpiredError.selector.revertWith();
        }

        // Prevent Replay Attacks by checking if the session was already recorded
        if (requestsProcessed[package.getSession()] != 0) {
            AlreadyUsedPayloadError.selector.revertWith();
        }

        // Validate caller identity. Package types 2 and 3 are exempt from strict caller binding.
        if (
            package.getTo() != _msgSender() && package.getPackageType() != 2 && package.getPackageType() != 3
                && package.getFrom() != _msgSender()
        ) {
            InvalidContractCallerError.selector.revertWith();
        }

        // @notice store requestID (session) to avoid replay
        requestsProcessed[package.getSession()] = block.timestamp;
        emit PureFiPackageProcessed(_msgSender(), package.getSession());

        return package;
    }

    /**
     * @notice Checks if the provided byte array meets the absolute minimum length requirements.
     * @dev Minimum size is calculated based on: timestamp (8 bytes) + signature (65 bytes) +
     * package type (1 byte) + session ID (32 bytes).
     * @param _payload The raw byte array to check.
     */
    function _checkPayloadLength(bytes calldata _payload) internal {
        // min package size = 8 (timestamp) + 65 (signature) + 1 (type) + 32 (session)
        if (_payload.length <= (8 + 65 + 1 + 32)) {
            TooShortPayloadError.selector.revertWith();
        }
    }

    // =============================================================
    // EXTERNAL FUNCTIONS (WITHDRAWALS / FEE MANAGEMENT)
    // =============================================================

    /**
     * @notice Withdraws accumulated native currency fees to an authorized fee collector.
     * @dev Implements a "Crank Pattern": Anyone can call this function and pay the gas,
     * but the funds will ONLY be sent to the specified `account`, which MUST possess the `FEE_COLLECTOR_ROLE`.
     * @param account The destination address for the withdrawn funds (must be a Fee Collector).
     * @param amount The amount of native tokens (wei) to withdraw.
     */
    function withdraw(address account, uint256 amount) external {
        _checkRole(FEE_COLLECTOR_ROLE, account);
        (bool success,) = payable(account).call{value: amount}("");

        if (!success) {
            WithdrawFailed.selector.revertWith();
        }

        emit Withdrawn(account, amount);
    }

    /**
     * @notice Withdraws accumulated ERC20 fees to an authorized fee collector.
     * @dev Implements a "Crank Pattern" similar to native withdrawals. The destination `account`
     * must possess the `FEE_COLLECTOR_ROLE`.
     * @param token The address of the ERC20 token to withdraw.
     * @param account The destination address for the withdrawn tokens (must be a Fee Collector).
     * @param amount The amount of ERC20 tokens to withdraw.
     */
    function withdrawERC20(address token, address account, uint256 amount) external {
        _checkRole(FEE_COLLECTOR_ROLE, account);
        IERC20(token).transfer(account, amount);
    }
}
