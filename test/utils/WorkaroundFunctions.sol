// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../src/libraries/SafePureFiValidate.sol";

import "forge-std/console.sol";

// @notice We need to use workaround contract because through external functions we can use memory data in functions that require calldata
// @notice More info: https://book.getfoundry.sh/tutorials/best-practices#workaround-functions
contract WorkaroundFunctions {
    using SafePureFiValidate for bytes;

    function workaround_packageType(bytes calldata data) external pure returns (uint8){
        return data.getPackageType();
    }

    function workaround_session(bytes calldata data) external pure returns (uint256){
        return data.getSession();
    }

    function workaround_rule(bytes calldata data) external pure returns (uint256){
        return data.getRule();
    }

    function workaround_from(bytes calldata data) external pure returns (address){
        return data.getFrom();
    }

    function workaround_to(bytes calldata data) external pure returns (address){
        return data.getTo();
    }

    function workaround_intermediary(bytes calldata data) external pure returns (address){
        return data.getIntermediary();
    }

    function workaround_payee(bytes calldata data) external pure returns (address){
        return data.getPayee();
    }

    function workaround_paymentData(bytes calldata data) external pure returns (address, uint256){
        return data.getPaymentData();
    }

    function workaround_tokenData0(bytes calldata data) external pure returns (address, uint256){
        return data.getTokenData0();
    }

    function workaround_tokenData1(bytes calldata data) external pure returns (address, uint256){
        return data.getTokenData1();
    }

    function workaround_token0(bytes calldata data) external pure returns (address){
        return data.getToken0();
    }

    function workaround_token0Amount(bytes calldata data) external pure returns (uint256){
        return data.getToken0Amount();
    }

    function workaround_encodeTokenData(address token, uint8 decimals, uint256 amount) public pure returns (uint256 encodedTokenData) {
        assembly{
            encodedTokenData := shl(8, token)
            encodedTokenData := add(decimals, encodedTokenData)
            encodedTokenData := shl(88, encodedTokenData)
            encodedTokenData := add(encodedTokenData, div(amount, exp(10, decimals)))
        }
    }
}
