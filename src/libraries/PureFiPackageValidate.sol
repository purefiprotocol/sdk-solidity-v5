// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {CustomRevert} from "./CustomRevert.sol";
import "forge-std/console.sol";
/*
(packagetype & 128 == 1) => has intermediary
(packagetype & 64 == 1) => has paymentdata
(packagetype & 32 == 1) => has token0
(packagetype & 16 == 1) => has token1
(packagetype == 1) => old type 1
(packagetype == 2) => old type 2

struct VerificationPackage{
        uint8 packagetype; 0
        uint256 session;   32
        uint256 rule;      64
        address from;      96
        address to;        128
        address intermediary;   160
        address payee;          192
        uint256 paymentData;    224
	uint256 tokenData0;         256
	uint256 tokenData1;         288
}*/

library PureFiPackageValidate {
    using PureFiPackageValidate for bytes;
    using CustomRevert for bytes4;

    error InsufficientDataLengthError();

    error MissingIntermediaryFlagError();


    function validateDataLength(bytes calldata data) internal pure {
        if (data.length < 181) {
            InsufficientDataLengthError.selector.revertWith();
        }
    }


    function getPackageType(bytes calldata data) internal pure returns (uint8 packageType) {
        assembly {
            packageType := calldataload(add(data.offset, 0))
        }
    }


    function getSession(bytes calldata data) internal pure returns (uint256 session) {
        assembly {
            session := calldataload(add(data.offset, 32))
        }
    }


    function getRule(bytes calldata data) internal pure returns (uint256 rule) {
        assembly {
            rule := calldataload(add(data.offset, 64))
        }
    }


    function getFrom(bytes calldata data) internal pure returns (address from) {
        assembly {
            from := calldataload(add(data.offset, 96))
        }
    }


    function getTo(bytes calldata data) internal pure returns (address to) {
        assembly {
            to := calldataload(add(data.offset, 128))
        }
    }


    function getIntermediary(bytes calldata data) internal pure returns (address intermediary) {
        console.log(data.length);
        uint256 offset;
        assembly {
            intermediary := calldataload(add(data.offset, 160))
            offset := data.offset
        }
        console.log(offset);
    }


    function getPayee(bytes calldata data) internal pure returns (address payee) {
        assembly {
            payee := calldataload(add(data.offset, 192))
        }
    }


    function getPaymentData(bytes calldata data) internal pure returns (address token, uint256 amount) {
        uint256 paymentData;
        assembly {
            paymentData := calldataload(add(data.offset, 224))
        }
        (token, amount) = parseTokenData(paymentData);
    }


    function getTokenData0(bytes calldata data) internal pure returns (address token, uint256 amount) {
        uint256 paymentData;
        assembly {
            paymentData := calldataload(add(data.offset, 256))
        }
        (token, amount) = parseTokenData(paymentData);
    }


    function getTokenData1(bytes calldata data) internal pure returns (address token, uint256 amount) {
        uint256 paymentData;
        assembly {
            paymentData := calldataload(add(data.offset, 288))
        }
        (token, amount) = parseTokenData(paymentData);
    }


    function parseTokenData(uint256 tokenData) internal pure returns (address token, uint256 amount) {
        assembly {
            token := and(tokenData, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            amount := shl(168, tokenData)
            amount := shr(168, amount)
            amount := mul(amount, exp(10, byte(20, tokenData)))
        }
    }
}