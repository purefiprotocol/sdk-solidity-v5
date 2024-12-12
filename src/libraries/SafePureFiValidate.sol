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
        uint8 packageType = getPackageType(data);

        // Check if Token0 data is present
        if ((packageType & 32) != 32) {
            revert MissingToken0DataError();
        }

        uint256 paymentData;

        // Determine correct offset based on package type
        if ((packageType & 224) == 224) {
            // Type 224 and 240: With Intermediary, With PaymentData
            assembly {
                paymentData := calldataload(add(data.offset, 256))
            }
        } else if ((packageType & 160) == 160) {
            // Type 160 and 176: With Intermediary, Without PaymentData
            assembly {
                paymentData := calldataload(add(data.offset, 192))
            }
        } else if ((packageType & 96) == 96) {
            // Type 96 and 112: Without Intermediary, With PaymentData
            assembly {
                paymentData := calldataload(add(data.offset, 224))
            }
        } else if ((packageType & 32) == 32) {
            // Type 48 and 32: Without Intermediary, Without PaymentData
            assembly {
                paymentData := calldataload(add(data.offset, 160))
            }
        }
        // Parse token data
        (token, amount) = parseTokenData(paymentData);
    }

    function getTokenData1(bytes calldata data) internal pure returns (address token, uint256 amount) {
        // Check if the required token data bit is set
        if ((getPackageType(data) & 16) != 16) {
            revert MissingToken1DataError();
        }

        uint256 paymentData;

        // Determine the correct offset based on package type
        if ((getPackageType(data) & 240) == 240) {
            // Type 240: With Intermediary, With PaymentData
            assembly {
                paymentData := calldataload(add(data.offset, 288))
            }
        } else if ((getPackageType(data) & 176) == 176) {
            // Type 176: With Intermediary, Without PaymentData
            assembly {
                paymentData := calldataload(add(data.offset, 224))
            }
        } else if ((getPackageType(data) & 112) == 112) {
            // Type 112: Without Intermediary, With PaymentData
            assembly {
                paymentData := calldataload(add(data.offset, 256))
            }
        } else if ((getPackageType(data) & 48) == 48) {
            // Type 48: Without Intermediary, Without PaymentData
            assembly {
                paymentData := calldataload(add(data.offset, 192))
            }
        }
        // Parse token data
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
