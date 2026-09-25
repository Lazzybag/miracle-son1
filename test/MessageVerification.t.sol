// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CCTPDirectMessageTest.sol";

/**
 * @title MessageVerification
 * @dev Tests for message structure verification in Circle's Iris
 */
contract MessageVerification is Test {
    CCTPDirectMessageTest public testContract;
    
    uint32 constant SEPOLIA_DOMAIN = 0;
    bytes32 constant TEST_RECIPIENT = bytes32(uint256(0x1234567890abcdef));
    
    function setUp() public {
        testContract = new CCTPDirectMessageTest();
    }
    
    function test_arbitraryMessageAcceptance() public {
        bytes memory arbitraryMessage = abi.encodePacked(
            "This is an arbitrary message",
            uint256(12345),
            address(0x1234567890123456789012345678901234567890)
        );
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            arbitraryMessage
        ) returns (uint64 nonce) {
            assertGt(nonce, 0, "Nonce should be greater than 0");
            console.log("Arbitrary message accepted with nonce:", nonce);
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Arbitrary message rejected: ", reason)));
        }
    }
    
    function test_minimalMessageStructure() public {
        try testContract.test_sendMalformedMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT
        ) returns (uint64 nonce) {
            assertGt(nonce, 0, "Minimal message accepted");
            console.log("Minimal message accepted with nonce:", nonce);
        } catch Error(string memory reason) {
            console.log("Minimal message rejected:", reason);
        }
    }
    
    function test_emptyMessageRejection() public {
        bytes memory emptyMessage = "";
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            emptyMessage
        ) {
            revert("Empty message should be rejected");
        } catch Error(string memory reason) {
            console.log("Empty message correctly rejected:", reason);
        }
    }
    
    function test_smallMessageAcceptance() public {
        bytes memory smallMessage = abi.encode(uint256(100), "small");
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            smallMessage
        ) returns (uint64 nonce) {
            assertTrue(nonce > 0, "Small message should be accepted");
        } catch {
            revert("Small message should be accepted");
        }
    }
    
    function test_largeMessageHandling() public {
        bytes memory largeMessage = new bytes(1000);
        for (uint i = 0; i < 1000; i++) {
            largeMessage[i] = bytes1(uint8(i % 256));
        }
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            largeMessage
        ) returns (uint64 nonce) {
            assertTrue(nonce > 0, "Large message handling");
        } catch Error(string memory reason) {
            console.log("Large message rejected -", reason);
        }
    }
    
    function test_encodedVsRawMessage() public {
        address testToken = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        uint256 testAmount = 1000e6;
        
        bytes memory encodedMessage = abi.encode(testToken, testAmount, TEST_RECIPIENT);
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            encodedMessage
        ) returns (uint64 nonce1) {
            console.log("Encoded message accepted, nonce:", nonce1);
        } catch {
            revert("Encoded message should be accepted");
        }
    }
    
    function test_messageStructureLogging() public {
        bytes memory testMessage = abi.encode(uint256(12345), address(0xabcd), "test");
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            testMessage
        ) returns (uint64 nonce) {
            assertTrue(nonce > 0);
        } catch {
            revert("Message should be accepted");
        }
    }
}
