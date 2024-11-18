// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IPureFiVerifier} from "./interfaces/IPureFiVerifier.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./libraries/CustomRevert.sol";

contract PureFiVerifier is AccessControlUpgradeable, IPureFiVerifier {

    function initialize() external initializer {
        __AccessControl_init_unchained();
    }

    function version() public pure returns(uint32){
        // 000.000.000 - Major.minor.internal
        return 5000000;
    }

    function validateAndDecode(bytes calldata pureFiData) external {

    }
}
