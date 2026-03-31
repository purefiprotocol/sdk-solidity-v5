// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/libraries/CustomRevert.sol";

contract RevertHelper {
    using CustomRevert for bytes4;

    error SimpleError();
    error ErrorWithAddress(address addr);
    error ErrorWithInt24(int24 value);
    error ErrorWithUint160(uint160 value);
    error ErrorWithTwoInt24(int24 value1, int24 value2);
    error ErrorWithTwoUint160(uint160 value1, uint160 value2);
    error ErrorWithTwoAddresses(address addr1, address addr2);

    function doRevertWithSelector() external pure {
        SimpleError.selector.revertWith();
    }

    function doRevertWithAddress(address addr) external pure {
        ErrorWithAddress.selector.revertWith(addr);
    }

    function doRevertWithInt24(int24 value) external pure {
        ErrorWithInt24.selector.revertWith(value);
    }

    function doRevertWithUint160(uint160 value) external pure {
        ErrorWithUint160.selector.revertWith(value);
    }

    function doRevertWithTwoInt24(int24 v1, int24 v2) external pure {
        ErrorWithTwoInt24.selector.revertWith(v1, v2);
    }

    function doRevertWithTwoUint160(uint160 v1, uint160 v2) external pure {
        ErrorWithTwoUint160.selector.revertWith(v1, v2);
    }

    function doRevertWithTwoAddresses(address a1, address a2) external pure {
        ErrorWithTwoAddresses.selector.revertWith(a1, a2);
    }

    function doBubbleUpAndRevertWith(address target, bytes4 fnSelector, bytes4 ctx) external pure {
        CustomRevert.bubbleUpAndRevertWith(target, fnSelector, ctx);
    }
}

contract MockRevertingContract {
    error SimpleError();
    error ParameterizedError(uint256 value, string msg);

    function simpleRevert() external pure {
        revert SimpleError();
    }

    function parameterizedRevert(uint256 value, string calldata payload) external pure {
        revert ParameterizedError(value, payload);
    }
}

contract CustomRevertTest is Test {
    RevertHelper private helper;
    MockRevertingContract private mockContract;

    function setUp() public {
        helper = new RevertHelper();
        mockContract = new MockRevertingContract();
    }

    function testRevertWithSelector() public {
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("SimpleError()"))));
        helper.doRevertWithSelector();
    }

    function testRevertWithAddress() public {
        address testAddr = address(0x1234567890123456789012345678901234567890);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ErrorWithAddress(address)")), testAddr));
        helper.doRevertWithAddress(testAddr);
    }

    function testRevertWithInt24() public {
        int24 testValue = 12345;
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ErrorWithInt24(int24)")), testValue));
        helper.doRevertWithInt24(testValue);
    }

    function testRevertWithMaxInt24() public {
        int24 testValue = type(int24).max;
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ErrorWithInt24(int24)")), testValue));
        helper.doRevertWithInt24(testValue);
    }

    function testRevertWithMinInt24() public {
        int24 testValue = type(int24).min;
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ErrorWithInt24(int24)")), testValue));
        helper.doRevertWithInt24(testValue);
    }

    function testRevertWithUint160() public {
        uint160 testValue = uint160(0x1234567890123456789012345678901234567890);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ErrorWithUint160(uint160)")), testValue));
        helper.doRevertWithUint160(testValue);
    }

    function testRevertWithTwoInt24() public {
        int24 v1 = 12345;
        int24 v2 = -6789;
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ErrorWithTwoInt24(int24,int24)")), v1, v2));
        helper.doRevertWithTwoInt24(v1, v2);
    }

    function testRevertWithTwoUint160() public {
        uint160 v1 = uint160(0x1234567890123456789012345678901234567890);
        uint160 v2 = uint160(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ErrorWithTwoUint160(uint160,uint160)")), v1, v2));
        helper.doRevertWithTwoUint160(v1, v2);
    }

    function testRevertWithTwoAddresses() public {
        address a1 = address(0x1234567890123456789012345678901234567890);
        address a2 = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ErrorWithTwoAddresses(address,address)")), a1, a2));
        helper.doRevertWithTwoAddresses(a1, a2);
    }

    function testAddressMasking() public {
        address testAddr = address(0x1234567890123456789012345678901234567890);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ErrorWithAddress(address)")), testAddr));
        helper.doRevertWithAddress(testAddr);
    }

    function testUint160Masking() public {
        uint160 testValue = uint160(0x1234567890123456789012345678901234567890);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ErrorWithUint160(uint160)")), testValue));
        helper.doRevertWithUint160(testValue);
    }

    function testInt24SignExtension() public {
        int24 negativeValue = -123;
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ErrorWithInt24(int24)")), negativeValue));
        helper.doRevertWithInt24(negativeValue);
    }

    // ── BubbleUp тесты ────────────────────────────────────────────────────────

    function testBubbleUpSimpleError() public {
        vm.expectRevert();
        helper.doBubbleUpAndRevertWith(
            address(mockContract), MockRevertingContract.simpleRevert.selector, bytes4(uint32(123))
        );
    }

    function testBubbleUpParameterizedError() public {
        vm.expectRevert();
        helper.doBubbleUpAndRevertWith(
            address(mockContract), MockRevertingContract.parameterizedRevert.selector, bytes4(uint32(456))
        );
    }

    function testBubbleUpWithPrank() public {
        address prankedAddress = address(0xdead);
        bytes4 selector = bytes4(keccak256("someFunction()"));
        bytes memory revertReason = abi.encodeWithSelector(bytes4(keccak256("Error(string)")), "Test error");

        vm.mockCallRevert(prankedAddress, abi.encodeWithSelector(selector), revertReason);

        vm.expectRevert();
        helper.doBubbleUpAndRevertWith(prankedAddress, selector, bytes4(uint32(789)));
    }
}
