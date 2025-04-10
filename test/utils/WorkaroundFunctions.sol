// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../src/libraries/PureFiDataLibrary.sol";

import "forge-std/console.sol";

// @notice We need to use workaround contract because through external functions we can use memory data in functions that require calldata
// @notice More info: https://book.getfoundry.sh/tutorials/best-practices#workaround-functions
contract WorkaroundFunctions {
    using PureFiDataLibrary for bytes;

    function workaround_packageType(bytes calldata data) external pure returns (uint8) {
        return data.getPackageType();
    }

    function workaround_session(bytes calldata data) external pure returns (uint256) {
        return data.getSession();
    }

    function workaround_rule(bytes calldata data) external pure returns (uint256) {
        return data.getRule();
    }

    function workaround_from(bytes calldata data) external pure returns (address) {
        return data.getFrom();
    }

    function workaround_to(bytes calldata data) external pure returns (address) {
        return data.getTo();
    }

    function workaround_intermediary(bytes calldata data) external pure returns (address) {
        return data.getIntermediary();
    }

    function workaround_payee(bytes calldata data) external pure returns (address) {
        return data.getPayee();
    }

    function workaround_paymentData(bytes calldata data) external pure returns (address, uint256) {
        return data.getPaymentData();
    }

    function workaround_tokenData0(bytes calldata data) external pure returns (address, uint256) {
        return data.getTokenData0();
    }

    function workaround_tokenData1(bytes calldata data) external pure returns (address, uint256) {
        return data.getTokenData1();
    }

    function workaround_token0(bytes calldata data) external pure returns (address) {
        return data.getToken0();
    }

    function workaround_token0Amount(bytes calldata data) external pure returns (uint256) {
        return data.getToken0Amount();
    }

    function workaround_parseTokenData(uint256 data) external pure returns (address, uint256) {
        return PureFiDataLibrary.parseTokenData(data);
    }
    /**
     * @dev Encodes token data into a single unsigned 256-bit integer
     * @param token Token address (160 bits)
     * @param decimals Token's decimal places (8 bits)
     * @param amount Normalized token value without decimal shift
     * @return encodedTokenData Unsigned 256-bit integer with encoded value structure:
     *   - Top 160 bits: token address
     *   - Next 8 bits: decimal places
     *   - Last 88 bits: amount
     *
     * @notice Input requirements:
     *   - For 0.1 ETH: decimals = 17, amount = 1
     *   - For 59999 wei: decimals = 0, amount = 59999
     *   - For 324 ETH: decimals = 18, amount = 324
     */

    function workaround_encodeTokenData(address token, uint8 decimals, uint256 amount)
        public
        pure
        returns (uint256 encodedTokenData)
    {
        assembly {
            encodedTokenData := shl(8, token)
            encodedTokenData := add(decimals, encodedTokenData)
            encodedTokenData := shl(88, encodedTokenData)
            encodedTokenData := add(encodedTokenData, amount)
        }
    }

    /**
     * @dev Workaround function to call PureFiDataLibrary.getPackage with calldata
     * @param data The input bytes calldata containing the full PureFi payload
     * @return package The package bytes extracted from the payload
     */
    function workaround_getPackage(bytes calldata data) external pure returns (bytes memory) {
        return PureFiDataLibrary.getPackage(data);
    }

    /**
     * @dev Workaround function to call PureFiDataLibrary.getTimestamp with calldata
     * @param data The input bytes calldata containing the full PureFi payload
     * @return timestamp The timestamp extracted from the payload as a 64-bit unsigned integer
     */
    function workaround_getTimestamp(bytes calldata data) external pure returns (uint64) {
        return PureFiDataLibrary.getTimestamp(data);
    }

    /**
     * @dev Workaround function to call PureFiDataLibrary.getSignature with calldata
     * @param data The input bytes calldata containing the full PureFi payload
     * @return signature The signature bytes extracted from the payload
     */
    function workaround_getSignature(bytes calldata data) external pure returns (bytes memory) {
        return PureFiDataLibrary.getSignature(data);
    }

    /**
     * @dev Workaround function to call PureFiDataLibrary.decodePureFiData with calldata
     * @param data The input bytes calldata containing the full PureFi payload
     * @return timestamp The timestamp extracted from the payload
     * @return signature The signature bytes extracted from the payload
     * @return package The package bytes extracted from the payload
     */
    function workaround_decodePureFiData(bytes calldata data)
        external
        pure
        returns (uint64, bytes memory, bytes memory)
    {
        (uint64 timestamp, bytes calldata signature, bytes calldata package) = PureFiDataLibrary.decodePureFiData(data);
        return (timestamp, signature, package); // Преобразуем calldata в memory для тестов
    }
}
