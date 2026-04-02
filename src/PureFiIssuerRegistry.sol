// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PureFiVerifier} from "./PureFiVerifier.sol";

/**
 * @title PureFiIssuerRegistry
 * @notice Acts as an administrative proxy and registry to manage issuers and roles
 * for the associated `PureFiVerifier` smart contract.
 * @dev Inherits from OpenZeppelin's `AccessControlUpgradeable` to provide Role-Based Access Control (RBAC).
 * This contract is designed to be deployed behind an upgradeable proxy. It expects to hold the
 * `DEFAULT_ADMIN_ROLE` within the linked `PureFiVerifier` contract to manage its roles successfully.
 */
contract PureFiIssuerRegistry is AccessControlUpgradeable {
    // =============================================================
    // EVENTS
    // =============================================================

    /**
     * @notice Emitted when a new issuer is successfully registered and granted the `ISSUER_ROLE`.
     * @param issuer The address of the newly added issuer.
     */
    event IssuerAdded(address indexed issuer);

    /**
     * @notice Emitted when an existing issuer is unregistered and their `ISSUER_ROLE` is revoked.
     * @param issuer The address of the removed issuer.
     */
    event IssuerRemoved(address indexed issuer);

    /**
     * @notice Emitted when the linked `PureFiVerifier` contract address is updated.
     * @param verifier The address of the newly set `PureFiVerifier` contract.
     */
    event VerifierSettle(address indexed verifier);

    // =============================================================
    // STATE VARIABLES
    // =============================================================

    /**
     * @notice The instance of the linked `PureFiVerifier` smart contract.
     * @dev All role management calls (grant/revoke) are forwarded to this contract instance.
     */
    PureFiVerifier public verifier;

    // =============================================================
    // FUNCTIONS
    // =============================================================

    /**
     * @notice Returns the current version of the registry contract.
     * @dev Versioning follows a custom `Major.minor.internal` format.
     * @return The integer representation of the version (e.g., 5015000).
     */
    function version() public pure returns (uint32) {
        // 000.000.000 - Major.minor.internal
        return 5020000;
    }

    /**
     * @notice Initializes the upgradeable contract and sets the initial administrative roles.
     * @dev Replaces the constructor for upgradeable contracts. Can only be called once.
     * @param _admin The address that will be granted the `DEFAULT_ADMIN_ROLE`.
     */
    function initialize(address _admin) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /**
     * @notice Registers a new PureFi Issuer by granting them the `ISSUER_ROLE` in the verifier.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param _issuer The address of the issuer to be registered.
     */
    function register(address _issuer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        verifier.grantRole(verifier.ISSUER_ROLE(), _issuer);
        emit IssuerAdded(_issuer);
    }

    /**
     * @notice Unregisters an existing PureFi Issuer by revoking their `ISSUER_ROLE` in the verifier.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param _issuer The address of the issuer to be unregistered.
     */
    function unregister(address _issuer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        verifier.revokeRole(verifier.ISSUER_ROLE(), _issuer);
        emit IssuerRemoved(_issuer);
    }

    /**
     * @notice Updates the linked `PureFiVerifier` contract instance.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`. Ensure that this registry
     * is granted the `DEFAULT_ADMIN_ROLE` in the new verifier contract before updating.
     * @param _verifier The address of the new `PureFiVerifier` contract.
     */
    function setVerifier(address _verifier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        verifier = PureFiVerifier(payable(_verifier));
        emit VerifierSettle(_verifier);
    }

    /**
     * @notice A generic proxy function to grant any specific custom role within the verifier contract.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param account The address receiving the role.
     * @param role The `bytes32` identifier of the role being granted.
     */
    function verifierGrantRole(address account, bytes32 role) external onlyRole(DEFAULT_ADMIN_ROLE) {
        verifier.grantRole(role, account);
    }

    /**
     * @notice A generic proxy function to revoke any specific custom role within the verifier contract.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param account The address losing the role.
     * @param role The `bytes32` identifier of the role being revoked.
     */
    function verifierRevokeRole(address account, bytes32 role) external onlyRole(DEFAULT_ADMIN_ROLE) {
        verifier.revokeRole(role, account);
    }
}
