// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../libraries/CustomRevert.sol";

library SafePureFiValidate {
    using CustomRevert for bytes4;

    error InsufficientDataLengthError();
    error MissingIntermediaryFlagError();
    error MissingPaymentDataError();
    error MissingToken0DataError();
    error MissingToken1DataError();
    error ExpectedSecondPackageTypeError();

    //    function validateDataLength(bytes calldata data) internal pure {
    //        if (data.length < 181) {
    //            InsufficientDataLengthError.selector.revertWith();
    //        }
    //    }

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
        if ((getPackageType(data) & 128) != 128) {
            MissingIntermediaryFlagError.selector.revertWith();
        }

        assembly {
            intermediary := calldataload(add(data.offset, 160))
        }
    }

    function getPayee(bytes calldata data) internal pure returns (address payee) {
        // можно сделать локальную переменную
        if ((getPackageType(data) & 64) != 64) {
            MissingPaymentDataError.selector.revertWith();
        }

        // If Type 192, 224, 240: it have intermediary
        if ((getPackageType(data) & 128) == 128) {
            assembly {
                payee := calldataload(add(data.offset, 192))
            }
        } else {
            // If Type 64, 96, 112: it dont have intermediary
            assembly {
                payee := calldataload(add(data.offset, 160))
            }
        }
    }

    function getPaymentData(bytes calldata data) internal pure returns (address token, uint256 amount) {
        // Can be replaced with the local variable(2 calls)
        if ((getPackageType(data) & 64) != 64) {
            MissingPaymentDataError.selector.revertWith();
        }

        uint256 paymentData;
        // If Type 192, 224, 240: it have intermediary and paymentData
        if ((getPackageType(data) & 128) == 128) {
            assembly {
                paymentData := calldataload(add(data.offset, 224))
            }
        } else {
            // If Type 64, 96, 112: it dont have intermediary, but have paymentData
            assembly {
                paymentData := calldataload(add(data.offset, 192))
            }
        }

        (token, amount) = parseTokenData(paymentData);
    }

    function getTokenData0(bytes calldata data) internal pure returns (address token, uint256 amount) {
        // Can be replaced with the local variable(2 calls)
        // Check PackageType
        if ((getPackageType(data) & 32) != 32) {
            MissingToken0DataError.selector.revertWith();
        }
        uint256 paymentData;

        // Type32 and Type48
        // Without Intermediary
        // Without PaymentData
        if (((getPackageType(data) & 128) != 128) && ((getPackageType(data) & 64) != 64)) {
            assembly {
                paymentData := calldataload(add(data.offset, 160))
            }
        }

        // Type160 and Type176
        // With Intermediary
        // Without PaymentData
        // Without Token1Data
        if (((getPackageType(data) & 128) == 128) && ((getPackageType(data) & 64) != 64)) {
            assembly {
                paymentData := calldataload(add(data.offset, 192))
            }
        }

        // Type224 and 240
        // With Intermediary
        // With PaymentData
        if (((getPackageType(data) & 128) == 128) && ((getPackageType(data) & 64) == 64)) {
            assembly {
                paymentData := calldataload(add(data.offset, 256))
            }
        }

        // Type112 and 96
        // Without Intermediary
        // With PaymentData
        if (((getPackageType(data) & 128) != 128) && ((getPackageType(data) & 64) == 64)) {
            assembly {
                paymentData := calldataload(add(data.offset, 224))
            }
        }

        (token, amount) = parseTokenData(paymentData);
    }

    function getTokenData1(bytes calldata data) internal pure returns (address token, uint256 amount) {
        // Check PackageType
        if ((getPackageType(data) & 16) != 16) {
            MissingToken1DataError.selector.revertWith();
        }
        uint256 paymentData;
        //Type240
        // With Intermediary
        // With PaymentData
        if (((getPackageType(data) & 128) == 128) && ((getPackageType(data) & 64) == 64)) {
            assembly {
                paymentData := calldataload(add(data.offset, 288))
            }
        }

        //Type176
        // With Intermediary
        // Without PaymentData
        if (((getPackageType(data) & 128) == 128) && ((getPackageType(data) & 64) != 64)) {
            assembly {
                paymentData := calldataload(add(data.offset, 224))
            }
        }

        //Type112
        // Without Intermediary
        // With PaymentData
        if (((getPackageType(data) & 128) != 128) && ((getPackageType(data) & 64) == 64)) {
            assembly {
                paymentData := calldataload(add(data.offset, 256))
            }
        }

        //Type48
        // Without Intermediary
        // With PaymentData
        if (((getPackageType(data) & 128) != 128) && ((getPackageType(data) & 64) != 64)) {
            assembly {
                paymentData := calldataload(add(data.offset, 192))
            }
        }

        (token, amount) = parseTokenData(paymentData);
    }

    function parseTokenData(uint256 tokenData) internal pure returns (address token, uint256 amount) {
        assembly {
            token := shr(96, tokenData)
            amount := shl(168, tokenData)
            amount := shr(168, amount)
            amount := mul(amount, exp(10, byte(20, tokenData)))
        }
    }

    function getToken0(bytes calldata data) internal pure returns (address token) {
        if (getPackageType(data) != 2) {
            ExpectedSecondPackageTypeError.selector.revertWith();
        }
        assembly {
            token := calldataload(add(data.offset, 160))
        }
    }

    function getToken0Amount(bytes calldata data) internal pure returns (uint256 amount) {
        if (getPackageType(data) != 2) {
            ExpectedSecondPackageTypeError.selector.revertWith();
        }
        assembly {
            amount := calldataload(add(data.offset, 192))
        }
    }
}
