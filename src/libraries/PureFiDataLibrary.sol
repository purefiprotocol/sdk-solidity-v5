// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/IPureFiVerifier.sol";
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
     * @notice Extracts the package type from the package data
     * @dev Reads the first byte (index 0) of the package data using inline assembly
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return packageType The type of package as an 8-bit unsigned integer
     *
     * @custom:bit-mapping Package type is determined by the first byte:
     * - Bit 7 (128): Indicates presence of intermediary
     * - Bit 6 (64): Indicates presence of payment data
     * - Bit 5 (32): Indicates presence of token0 data
     * - Bit 4 (16): Indicates presence of token1 data
     * - Lower bits represent specific package variations
     */
    function getPackageType(bytes calldata package) internal pure returns (uint8 packageType) {
        assembly {
            packageType := calldataload(add(package.offset, 0))
        }
    }

    /**
     * @notice Extracts the session identifier from the package data
     * @dev Reads 32 bytes starting at offset 32 using inline assembly
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return session The session identifier as a 256-bit unsigned integer
     */
    function getSession(bytes calldata package) internal pure returns (uint256 session) {
        assembly {
            session := calldataload(add(package.offset, 32))
        }
    }

    /**
     * @notice Extracts the rule identifier from the package data
     * @dev Reads 32 bytes starting at offset 64 using inline assembly
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return rule The rule identifier as a 256-bit unsigned integer
     */
    function getRule(bytes calldata package) internal pure returns (uint256 rule) {
        assembly {
            rule := calldataload(add(package.offset, 64))
        }
    }

    /**
     * @notice Extracts the sender (from) address from the package data
     * @dev Reads 32 bytes starting at offset 96 using inline assembly
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return from The address of the sender
     */
    function getFrom(bytes calldata package) internal pure returns (address from) {
        assembly {
            from := calldataload(add(package.offset, 96))
        }
    }

    /**
     * @notice Extracts the recipient (to) address from the package data
     * @dev Reads 32 bytes starting at offset 128 using inline assembly
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return to The address of the recipient
     */
    function getTo(bytes calldata package) internal pure returns (address to) {
        assembly {
            to := calldataload(add(package.offset, 128))
        }
    }

    /**
     * @notice Extracts the intermediary address from the package data
     * @dev Reads 32 bytes starting at offset 160 using inline assembly
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return intermediary The address of the intermediary
     * @custom:security Reverts if the intermediary flag is not set in the package type
     */
    function getIntermediary(bytes calldata package) internal pure returns (address intermediary) {
        if ((getPackageType(package) & 128) != 128) {
            MissingIntermediaryFlagError.selector.revertWith();
        }

        assembly {
            intermediary := calldataload(add(package.offset, 160))
        }
    }

    /**
     * @notice Extracts the payee address from the package data
     * @dev Determines payee address location based on package type and presence of intermediary
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return payee The address of the payee
     * @custom:security Reverts if payment data flag is not set in the package type
     *
     * @custom:note Payee address location depends on package type:
     * - For types with intermediary (192, 224, 240): Payee at offset 192
     * - For types without intermediary (64, 96, 112): Payee at offset 160
     */
    function getPayee(bytes calldata package) internal pure returns (address payee) {
        if ((getPackageType(package) & 64) != 64) {
            MissingPaymentDataError.selector.revertWith();
        }

        // If Type 192, 224, 240: it has intermediary
        if ((getPackageType(package) & 128) == 128) {
            assembly {
                payee := calldataload(add(package.offset, 192))
            }
        } else {
            // If Type 64, 96, 112: it doesn't have intermediary
            assembly {
                payee := calldataload(add(package.offset, 160))
            }
        }
    }

    /**
     * @notice Extracts payment data (token address and amount) from the package data
     * @dev Determines payment data location based on package type and presence of intermediary
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return token The address of the token to be used for payment
     * @return amount The amount of the token to be paid
     * @custom:security Reverts if payment data flag is not set in the package type
     */
    function getPaymentData(bytes calldata package) internal pure returns (address token, uint256 amount) {
        if ((getPackageType(package) & 64) != 64) {
            MissingPaymentDataError.selector.revertWith();
        }

        uint256 paymentData;
        // If Type 192, 224, 240: it has intermediary and paymentData
        if ((getPackageType(package) & 128) == 128) {
            assembly {
                paymentData := calldataload(add(package.offset, 224))
            }
        } else {
            // If Type 64, 96, 112: it doesn't have intermediary, but has paymentData
            assembly {
                paymentData := calldataload(add(package.offset, 192))
            }
        }

        (token, amount) = parseTokenData(paymentData);
    }

    /**
     * @notice Extracts token0 data (token address and amount) from the package data
     * @dev Determines token0 data location based on package type
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return token The address of token0
     * @return amount The amount of token0
     * @custom:security Reverts if token0 data flag is not set in the package type
     */
    function getTokenData0(bytes calldata package) internal pure returns (address token, uint256 amount) {
        uint8 packageType = getPackageType(package);

        // Check if Token0 data is present
        if ((packageType & 32) != 32) {
            revert MissingToken0DataError();
        }

        uint256 paymentData;

        // Determine correct offset based on package type
        if ((packageType & 224) == 224) {
            // Type 224 and 240: With Intermediary, With PaymentData
            assembly {
                paymentData := calldataload(add(package.offset, 256))
            }
        } else if ((packageType & 160) == 160) {
            // Type 160 and 176: With Intermediary, Without PaymentData
            assembly {
                paymentData := calldataload(add(package.offset, 192))
            }
        } else if ((packageType & 96) == 96) {
            // Type 96 and 112: Without Intermediary, With PaymentData
            assembly {
                paymentData := calldataload(add(package.offset, 224))
            }
        } else if ((packageType & 32) == 32) {
            // Type 32 and 48: Without Intermediary, Without PaymentData
            assembly {
                paymentData := calldataload(add(package.offset, 160))
            }
        }
        // Parse token data
        (token, amount) = parseTokenData(paymentData);
    }

    /**
     * @notice Extracts token1 data (token address and amount) from the package data
     * @dev Determines token1 data location based on package type
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return token The address of token1
     * @return amount The amount of token1
     * @custom:security Reverts if token1 data flag is not set in the package type
     */
    function getTokenData1(bytes calldata package) internal pure returns (address token, uint256 amount) {
        // Check if the required token data bit is set
        if ((getPackageType(package) & 16) != 16) {
            revert MissingToken1DataError();
        }

        uint256 paymentData;

        // Determine the correct offset based on package type
        if ((getPackageType(package) & 240) == 240) {
            // Type 240: With Intermediary, With PaymentData
            assembly {
                paymentData := calldataload(add(package.offset, 288))
            }
        } else if ((getPackageType(package) & 176) == 176) {
            // Type 176: With Intermediary, Without PaymentData
            assembly {
                paymentData := calldataload(add(package.offset, 224))
            }
        } else if ((getPackageType(package) & 112) == 112) {
            // Type 112: Without Intermediary, With PaymentData
            assembly {
                paymentData := calldataload(add(package.offset, 256))
            }
        } else if ((getPackageType(package) & 48) == 48) {
            // Type 48: Without Intermediary, Without PaymentData
            assembly {
                paymentData := calldataload(add(package.offset, 192))
            }
        }
        // Parse token data
        (token, amount) = parseTokenData(paymentData);
    }

    /**
     * @notice Parses token data from a packed uint256 value
     * @dev The token data is packed as follows:
     *      - Bits 0-87: Token amount (88 bits)
     *      - Bits 96-255: Token address (160 bits, with bits 160-167 used as multiplier)
     *      - Bits 160-167: Multiplier (e.g., decimals, 8 bits)
     * @param tokenData The packed token data as a uint256
     * @return token The address of the token
     * @return amount The amount of the token, adjusted by the multiplier
     */
    function parseTokenData(uint256 tokenData) internal pure returns (address token, uint256 amount) {
        assembly {
            token := shr(96, tokenData)
            amount := shl(168, tokenData)
            amount := shr(168, amount)
            amount := mul(amount, exp(10, byte(20, tokenData)))
        }
    }

    /**
     * @notice Extracts the token0 address from the package data for package type 2
     * @dev Reads 32 bytes starting at offset 160 using inline assembly
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return token The address of token0
     * @custom:security Reverts if the package type is not 2
     */
    function getToken0(bytes calldata package) internal pure returns (address token) {
        if (getPackageType(package) != 2) {
            ExpectedSecondPackageTypeError.selector.revertWith();
        }
        assembly {
            token := calldataload(add(package.offset, 160))
        }
    }

    /**
     * @notice Extracts the token0 amount from the package data for package type 2
     * @dev Reads 32 bytes starting at offset 192 using inline assembly
     * @param package The bytes calldata representing the package, obtained from `getPackage` or `decodePureFiData`
     * @return amount The amount of token0
     * @custom:security Reverts if the package type is not 2
     */
    function getToken0Amount(bytes calldata package) internal pure returns (uint256 amount) {
        if (getPackageType(package) != 2) {
            ExpectedSecondPackageTypeError.selector.revertWith();
        }
        assembly {
            amount := calldataload(add(package.offset, 192))
        }
    }

    /**
     * @notice Decodes the full PureFi payload into its components
     * @dev Extracts timestamp, signature, and package from the input payload using inline assembly
     * @param data The input bytes calldata containing the full PureFi payload
     * @return timestamp The timestamp of the payload as a 64-bit unsigned integer
     * @return signature The signature bytes of the payload
     * @return package The package bytes to be used with other library functions
     */
    function decodePureFiData(bytes calldata data) internal pure returns (uint64, bytes calldata, bytes calldata) {
        PureFiData calldata pureFiData;
        assembly ("memory-safe") {
            pureFiData := data.offset
        }
        return (pureFiData.timestamp, pureFiData.signature, pureFiData.package);
    }

    /**
     * @notice Extracts the package data from the full PureFi payload
     * @dev Extracts the package portion of the payload using inline assembly
     * @param data The input bytes calldata containing the full PureFi payload
     * @return package The package bytes to be used with other library functions
     */
    function getPackage(bytes calldata data) internal pure returns (bytes calldata) {
        PureFiData calldata pureFiData;
        assembly ("memory-safe") {
            pureFiData := data.offset
        }
        return pureFiData.package;
    }

    /**
     * @notice Extracts the timestamp from the full PureFi payload
     * @dev Extracts the timestamp portion of the payload using inline assembly
     * @param data The input bytes calldata containing the full PureFi payload
     * @return timestamp The timestamp of the payload as a 64-bit unsigned integer
     */
    function getTimestamp(bytes calldata data) internal pure returns (uint64) {
        PureFiData calldata pureFiData;
        assembly ("memory-safe") {
            pureFiData := data.offset
        }
        return pureFiData.timestamp;
    }

    /**
     * @notice Extracts the signature from the full PureFi payload
     * @dev Extracts the signature portion of the payload using inline assembly
     * @param data The input bytes calldata containing the full PureFi payload
     * @return signature The signature bytes of the payload
     */
    function getSignature(bytes calldata data) internal pure returns (bytes calldata) {
        PureFiData calldata pureFiData;
        assembly ("memory-safe") {
            pureFiData := data.offset
        }
        return pureFiData.signature;
    }
}