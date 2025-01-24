pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PureFiVerifier} from "./PureFiVerifier.sol";

contract PureFiIssuerRegistry is AccessControlUpgradeable {
    event IssuerAdded(address indexed issuer);
    event IssuerRemoved(address indexed issuer);
    event VerifierSettle(address indexed verifier);

    PureFiVerifier public verifier;

    function version() public pure returns (uint32) {
        // 000.000.000 - Major.minor.internal
        return 2000000;
    }

    function initialize(address _admin) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function register(address _issuer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        verifier.grantRole(verifier.ISSUER_ROLE(), _issuer);
        emit IssuerAdded(_issuer);
    }

    function unregister(address _issuer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        verifier.revokeRole(verifier.ISSUER_ROLE(), _issuer);
        emit IssuerRemoved(_issuer);
    }

    function setVerifier(address _verifier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        verifier = PureFiVerifier(_verifier);
        emit VerifierSettle(_verifier);
    }
}
