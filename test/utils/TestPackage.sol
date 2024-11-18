// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IPackageTypes} from "./interfaces/IPackageTypes.sol";

contract TestPackage is IPackageTypes {
    uint256 public SESSION = 12345;
    uint256 public RULE = 67890;
    address public FROM = address(0xC4356aF40cc379b15925Fc8C21e52c00F474e8e9);
    address public TO = address(0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5);
    address public INTERMEDIARY = 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97;
    address public PAYEE = address(0xeBec795c9c8bBD61FFc14A6662944748F299cAcf);
    //uint256 public PAYMENT_DATA = 0xcda4e840411c00a614ad9205caec807c7458a0e31200000000000000038DBBAB;
    uint256 public PAYMENT_DATA = 0xcda4e840411c00a614ad9205caec807c7458a0e30006F85BB78788D24BC39480;
    uint256 public TOKEN_DATA_0 = 0xcda4e840411c00a614ad9205caec807c7458a0e30006F85BB78788D24BC39480;
    uint256 public TOKEN_DATA_1 = 0xcda4e840411c00a614ad9205caec807c7458a0e30006F85BB78788D24BC39480;
    address public TOKEN_0 = 0xcaEc807C7458A0E30006f85BB78788d24bC39480;
    uint256 public TOKEN_0_AMOUNT = 8426393683839422222800000;
    //uint8 public DECIMALS = 18;
    uint8 public DECIMALS = 0;

    uint8 public constant PACKAGE_TYPE_1 = 1;
    uint8 public constant PACKAGE_TYPE_2 = 2;
    uint8 public constant PACKAGE_TYPE_32 = 32;
    uint8 public constant PACKAGE_TYPE_48 = 48;
    uint8 public constant PACKAGE_TYPE_64 = 64;
    uint8 public constant PACKAGE_TYPE_96 = 96;
    uint8 public constant PACKAGE_TYPE_112 = 112;
    uint8 public constant PACKAGE_TYPE_128 = 128;
    uint8 public constant PACKAGE_TYPE_160 = 160;
    uint8 public constant PACKAGE_TYPE_176 = 176;
    uint8 public constant PACKAGE_TYPE_192 = 192;
    uint8 public constant PACKAGE_TYPE_224 = 224;
    uint8 public constant PACKAGE_TYPE_240 = 240;


    function getTestPackageType1() public view returns (PackageType1 memory) {
        return PackageType1(
            PACKAGE_TYPE_1,
            SESSION,
            RULE,
            FROM,
            TO);
    }


    function getTestPackageType2() public view returns (PackageType2 memory) {
        return PackageType2(
            PACKAGE_TYPE_2,
            SESSION,
            RULE,
            FROM,
            TO,
            TOKEN_0,
            TOKEN_0_AMOUNT);
    }


    function getTestPackageType32() public view returns (PackageType32 memory) {
        return PackageType32(
            PACKAGE_TYPE_32,
            SESSION,
            RULE,
            FROM,
            TO,
            TOKEN_DATA_0);
    }


    function getTestPackageType48() public view returns (PackageType48 memory) {
        return PackageType48(
            PACKAGE_TYPE_48,
            SESSION,
            RULE,
            FROM,
            TO,
            TOKEN_DATA_0,
            TOKEN_DATA_1);
    }


    function getTestPackageType64() public view returns (PackageType64 memory) {
        return PackageType64(
            PACKAGE_TYPE_64,
            SESSION,
            RULE,
            FROM,
            TO,
            PAYEE,
            PAYMENT_DATA);
    }


    function getTestPackageType96() public view returns (PackageType96 memory) {
        return PackageType96(
            PACKAGE_TYPE_96,
            SESSION,
            RULE,
            FROM,
            TO,
            PAYEE,
            PAYMENT_DATA,
            TOKEN_DATA_0);
    }


    function getTestPackageType112() public view returns (PackageType112 memory) {
        return PackageType112(
            PACKAGE_TYPE_112,
            SESSION,
            RULE,
            FROM,
            TO,
            PAYEE,
            PAYMENT_DATA,
            TOKEN_DATA_0,
            TOKEN_DATA_1);
    }


    function getTestPackageType128() public view returns (PackageType128 memory) {
        return PackageType128(
            PACKAGE_TYPE_128,
            SESSION,
            RULE,
            FROM,
            TO,
            INTERMEDIARY,
            TOKEN_DATA_0);
    }


    function getTestPackageType160() public view returns (PackageType160 memory) {
        return PackageType160(
            PACKAGE_TYPE_160,
            SESSION,
            RULE,
            FROM,
            TO,
            INTERMEDIARY,
            TOKEN_DATA_0);
    }


    function getTestPackageType176() public view returns (PackageType176 memory) {
        return PackageType176(
            PACKAGE_TYPE_176,
            SESSION,
            RULE,
            FROM,
            TO,
            INTERMEDIARY,
            TOKEN_DATA_0,
            TOKEN_DATA_1);
    }


    function getTestPackageType192() public view returns (PackageType192 memory) {
        return PackageType192(
            PACKAGE_TYPE_192,
            SESSION,
            RULE,
            FROM,
            TO,
            INTERMEDIARY,
            PAYEE,
            PAYMENT_DATA);
    }


    function getTestPackageType224() public view returns (PackageType224 memory) {
        return PackageType224(
            PACKAGE_TYPE_224,
            SESSION,
            RULE,
            FROM,
            TO,
            INTERMEDIARY,
            PAYEE,
            PAYMENT_DATA,
            TOKEN_DATA_0);
    }


    function getTestPackageType240() public view returns (PackageType240 memory) {
        return PackageType240(
            PACKAGE_TYPE_240,
            SESSION,
            RULE,
            FROM,
            TO,
            INTERMEDIARY,
            PAYEE,
            PAYMENT_DATA,
            TOKEN_DATA_0,
            TOKEN_DATA_1);
    }
}
