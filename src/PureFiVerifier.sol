// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "./interfaces/IPureFiVerifier.sol";
import "./libraries/CustomRevert.sol";
import {SafePureFiValidate} from "./libraries/SafePureFiValidate.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";

contract PureFiVerifier is AccessControlUpgradeable, IPureFiVerifier, ReentrancyGuardTransientUpgradeable {
    using CustomRevert for bytes4;
    using SafePureFiValidate for bytes;

    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    mapping(uint256 => uint256) public requestsProcessed;
    uint256 public graceTime;

    event PureFiPackageProcessed(address indexed caller, uint256 session);

    error PureFiDataExpiredError();
    error TooShortPayloadError();
    error AlreadyUsedPayloadError();
    error InvalidContractCallerError();

    function initialize(address issuerRegistry) external initializer {
        // @notice 10 min * 60 seconds = 600 seconds
        // @notice block.timestamp in seconds, so we need to operate with seconds
        graceTime = 10 * 60;

        __AccessControl_init_unchained();
        _grantRole(DEFAULT_ADMIN_ROLE, issuerRegistry);
    }

    // TODO Clarify about clearStorage() function

    function validatePayload(bytes calldata _payload) external nonReentrant {
        _validatePayload(_payload);
    }

    function decodePureFiPackage(bytes calldata _pureFiPackage) external pure returns (VerificationPackage memory) {
        return VerificationPackage(
            _pureFiPackage.getPackageType(),
            _pureFiPackage.getSession(),
            _pureFiPackage.getRule(),
            _pureFiPackage.getFrom(),
            _pureFiPackage.getTo(),
            _pureFiPackage.getToken0(),
            _pureFiPackage.getToken0Amount(),
            /// TODO payload ???
            ""
        );
    }

    function validateAndDecode(bytes calldata _purefidata)
        external
        override
        nonReentrant
        returns (VerificationPackage memory)
    {
        bytes calldata package = _validatePayload(_purefidata);

        return VerificationPackage(
            package.getPackageType(),
            package.getSession(),
            package.getRule(),
            package.getFrom(),
            package.getTo(),
            package.getToken0(),
            package.getToken0Amount(),
            /// TODO payload ???
            ""
        );
    }

    function validatePureFiData(bytes calldata _purefidata)
        external
        override
        nonReentrant
        returns (bytes calldata, uint16)
    {
        // TODO why 0?
        return (_validatePayload(_purefidata), 0);
    }

    function version() public pure returns (uint32) {
        // 000.000.000 - Major.minor.internal
        return 5000000;
    }

    function _validatePayload(bytes calldata _payload) internal returns (bytes calldata) {
        //min package size = 8+65 +1+32
        if (_payload.length <= (8 + 65 + 1 + 32)) {
            TooShortPayloadError.selector.revertWith();
        }
        PureFiData calldata pureFiData;

        assembly ("memory-safe") {
            pureFiData := _payload.offset
        }

        (address recovered,,) = ECDSA.tryRecover(
            keccak256(abi.encodePacked(pureFiData.timestamp, pureFiData.package)), pureFiData.signature
        );
        _checkRole(ISSUER_ROLE, recovered);

        if (block.timestamp > pureFiData.timestamp + graceTime) {
            PureFiDataExpiredError.selector.revertWith();
        }

        if (requestsProcessed[pureFiData.package.getSession()] != 0) {
            AlreadyUsedPayloadError.selector.revertWith();
        }

        //        if (!((pureFiData.package.getTo() == msg.sender) || ((pureFiData.package.getPackageType() == 2 || pureFiData.package.getPackageType() == 3) && pureFiData.package.getFrom() == _msgSender()))) {
        //            InvalidContractCallerError.selector.revertWith();
        //        }

        // TODO check condition below more detailed
        if (
            pureFiData.package.getTo() != msg.sender && pureFiData.package.getPackageType() != 2
                && pureFiData.package.getPackageType() != 3 && pureFiData.package.getFrom() != _msgSender()
        ) {
            InvalidContractCallerError.selector.revertWith();
        }

        // @notice store requestID to avoid replay
        requestsProcessed[pureFiData.package.getSession()] = block.timestamp;
        emit PureFiPackageProcessed(_msgSender(), pureFiData.package.getSession());

        return pureFiData.package;
    }
}
