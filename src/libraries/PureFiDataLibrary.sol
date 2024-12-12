// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../libraries/CustomRevert.sol";

library PureFiDataLibrary {
    using CustomRevert for bytes4;

    error InsufficientDataLengthError();
    error MissingIntermediaryFlagError();
    error MissingPaymentDataError();
    error MissingToken0DataError();
    error MissingToken1DataError();
    error ExpectedSecondPackageTypeError();

    /**
     * @notice Extracts the package type from the input data
     * @dev Reads the first byte (index 0) of the input data using inline assembly
     * @param data The input bytes calldata containing package information
     * @return packageType The type of package as an 8-bit unsigned integer
     *
     * @custom:bit-mapping Package type is determined by the first byte:
     * - Bit 7 (128): Indicates presence of intermediary
     * - Bit 6 (64): Indicates presence of payment data
     * - Lower bits represent specific package variations
     */
    function getPackageType(bytes calldata data) internal pure returns (uint8 packageType) {
        assembly {
            packageType := calldataload(add(data.offset, 0))
        }
    }

    /**
     * @notice Extracts the session identifier from the input data
     * @dev Reads 32 bytes starting at offset 32 using inline assembly
     * @param data The input bytes calldata containing session information
     * @return session The session identifier as a 256-bit unsigned integer
     */
    function getSession(bytes calldata data) internal pure returns (uint256 session) {
        assembly {
            session := calldataload(add(data.offset, 32))
        }
    }

    /**
     * @notice Extracts the rule identifier from the input data
     * @dev Reads 32 bytes starting at offset 64 using inline assembly
     * @param data The input bytes calldata containing rule information
     * @return rule The rule identifier as a 256-bit unsigned integer
     */
    function getRule(bytes calldata data) internal pure returns (uint256 rule) {
        assembly {
            rule := calldataload(add(data.offset, 64))
        }
    }

    /**
     * @notice Extracts the sender (from) address from the input data
     * @dev Reads 32 bytes starting at offset 96 using inline assembly
     * @param data The input bytes calldata containing sender information
     * @return from The address of the sender
     */
    function getFrom(bytes calldata data) internal pure returns (address from) {
        assembly {
            from := calldataload(add(data.offset, 96))
        }
    }

    /**
     * @notice Extracts the recipient (to) address from the input data
     * @dev Reads 32 bytes starting at offset 128 using inline assembly
     * @param data The input bytes calldata containing recipient information
     * @return to The address of the recipient
     */
    function getTo(bytes calldata data) internal pure returns (address to) {
        assembly {
            to := calldataload(add(data.offset, 128))
        }
    }

    /**
     * @notice Extracts the intermediary address from the input data
     * @dev Reads 32 bytes starting at offset 160 using inline assembly
     * @param data The input bytes calldata containing intermediary information
     * @return intermediary The address of the intermediary
     * @custom:security Reverts if the intermediary flag is not set in the package type
     */
    function getIntermediary(bytes calldata data) internal pure returns (address intermediary) {
        if ((getPackageType(data) & 128) != 128) {
            MissingIntermediaryFlagError.selector.revertWith();
        }

        assembly {
            intermediary := calldataload(add(data.offset, 160))
        }
    }

    /**
     * @notice Extracts the payee address from the input data
     * @dev Determines payee address location based on package type and presence of intermediary
     * @param data The input bytes calldata containing payee information
     * @return payee The address of the payee
     * @custom:security Reverts if payment data flag is not set in the package type
     *
     * @custom:note Payee address location depends on package type:
     * - For types with intermediary (192, 224, 240): Payee at offset 192
     * - For types without intermediary (64, 96, 112): Payee at offset 160
     */
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

    /// @dev Extracts payment data (token address and amount) from a byte array representing a package.
    ///
    /// Reverts with `MissingPaymentDataError` if the package type does not indicate the presence of payment data.
    ///
    /// @param data The byte array containing the package data.
    /// @return token The address of the token to be used for payment.
    /// @return amount The amount of the token to be paid.
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

    /// @dev Extracts token data (token address and amount) from a byte array representing a package.
    ///
    /// Reverts with `MissingToken0DataError` if the package type does not indicate the presence of token0 data.
    ///
    /// @param data The byte array containing the package data.
    /// @return token The address of the token.
    /// @return amount The amount of the token.
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

    /// @dev Extracts token data (token address and amount) from a byte array representing a package.
    ///
    /// Reverts with `MissingToken1DataError` if the package type does not indicate the presence of token0 data.
    ///
    /// @param data The byte array containing the package data.
    /// @return token The address of the token.
    /// @return amount The amount of the token.
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

    /// @dev Parses token data from a packed uint256 value.
    ///
    /// The token data is packed as follows:
    /// - Bits 0-95: Token amount
    /// - Bits 96-255: Token address
    ///
    /// @param tokenData The packed token data.
    /// @return token The address of the token.
    /// @return amount The amount of the token.
    function parseTokenData(uint256 tokenData) internal pure returns (address token, uint256 amount) {
        assembly {
            token := shr(96, tokenData)
            amount := shl(168, tokenData)
            amount := shr(168, amount)
            amount := mul(amount, exp(10, byte(20, tokenData)))
        }
    }

    /// @dev Extracts the token0 address from a byte array representing a package of type 2.
    ///
    /// Reverts with `ExpectedSecondPackageTypeError` if the package type is not 2.
    ///
    /// @param data The byte array containing the package data.
    /// @return token The address of the token0.
    function getToken0(bytes calldata data) internal pure returns (address token) {
        if (getPackageType(data) != 2) {
            ExpectedSecondPackageTypeError.selector.revertWith();
        }
        assembly {
            token := calldataload(add(data.offset, 160))
        }
    }

    /// @dev Extracts the token0 amount from a byte array representing a package of type 2.
    ///
    /// Reverts with `ExpectedSecondPackageTypeError` if the package type is not 2.
    ///
    /// @param data The byte array containing the package data.
    /// @return amount The amount of the token0.
    function getToken0Amount(bytes calldata data) internal pure returns (uint256 amount) {
        if (getPackageType(data) != 2) {
            ExpectedSecondPackageTypeError.selector.revertWith();
        }
        assembly {
            amount := calldataload(add(data.offset, 192))
        }
    }
}
