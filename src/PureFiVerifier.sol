// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "./interfaces/IPureFiVerifier.sol";
import "./libraries/CustomRevert.sol";
import {PureFiDataLibrary} from "./libraries/PureFiDataLibrary.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";

contract PureFiVerifier is AccessControlUpgradeable, IPureFiVerifier, ReentrancyGuardTransientUpgradeable {
    using CustomRevert for bytes4;
    using PureFiDataLibrary for bytes;

    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    mapping(uint256 => uint256) public requestsProcessed;
    uint256 public graceTime;

    event PureFiPackageProcessed(address indexed caller, uint256 session);
    event PureFiStorageClear(address caller, uint256 sessionId);

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

    function validatePayload(bytes calldata _payload) external nonReentrant {
        _validatePayload(_payload);
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
