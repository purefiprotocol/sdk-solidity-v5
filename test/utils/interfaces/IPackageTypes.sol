// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract IPackageTypes {
    struct PackageType1 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
    }

    struct PackageType2 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        address token0;
        uint256 tokenAmount0;
    }

    struct PackageType32 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        uint256 tokenData0;
    }

    struct PackageType48 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        uint256 tokenData0;
        uint256 tokenData1;
    }

    struct PackageType64 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        address payee;
        uint256 paymentData;
    }

    struct PackageType96 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        address payee;
        uint256 paymentData;
        uint256 tokenData0;
    }

    struct PackageType112 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        address payee;
        uint256 paymentData;
        uint256 tokenData0;
        uint256 tokenData1;
    }

    struct PackageType128 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        address intermediary;
        uint256 tokenData0;
    }

    struct PackageType160 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        address intermediary;
        uint256 tokenData0;
    }

    struct PackageType176 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        address intermediary;
        uint256 tokenData0;
        uint256 tokenData1;
    }

    struct PackageType192 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        address intermediary;
        address payee;
        uint256 paymentData;
    }

    struct PackageType224 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        address intermediary;
        address payee;
        uint256 paymentData;
        uint256 tokenData0;
    }

    struct PackageType240 {
        uint8 packageType;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        address intermediary;
        address payee;
        uint256 paymentData;
        uint256 tokenData0;
        uint256 tokenData1;
    }
}
