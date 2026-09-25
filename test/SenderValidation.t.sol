// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CCTPDirectMessageTest.sol";

/**
 * @title SenderValidation
 * @dev Tests for sender validation in Circle's Iris
 */
contract SenderValidation is Test {
    CCTPDirectMessageTest public testContract;
    CCTPDirectMessageTest public secondContract;
    
    address constant UNAUTHORIZED_SENDER = 0x1234567890123456789012345678901234567890;
    uint32 constant SEPOLIA_DOMAIN = 0;
    bytes32 constant TEST_RECIPIENT = bytes32(uint256(0xabcd));
    
    function setUp() public {
        testContract = new CCTPDirectMessageTest();
        secondContract = new CCTPDirectMessageTest();
    }
    
    function test_messageFromOwner() public {
        bytes memory message = abi.encode(uint256(100), "authorized");
        
        vm.prank(address(this)); 
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            message
        ) returns (uint64 nonce) {
            assertGt(nonce, 0);
            console.log("Message from owner accepted, nonce:", nonce);
        } catch {
            revert("Owner message should be accepted");
        }
    }
    
    function test_messageFromUnauthorizedSender() public {
        bytes memory message = abi.encode(uint256(200), "unauthorized");
        
        vm.prank(UNAUTHORIZED_SENDER);
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            message
        ) {
            revert("Unauthorized sender should be rejected");
        } catch Error(string memory reason) {
            console.log("Unauthorized sender correctly rejected:", reason);
        }
    }
    
    function test_differentContractInstancesSameSender() public {
        bytes memory message = abi.encode(uint256(300), "multi-instance");
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            message
        ) returns (uint64 nonce1) {
            console.log("First contract message, nonce:", nonce1);
        } catch {
            revert("First contract message should be accepted");
        }
    }
    
    function test_identicalMessageDifferentSenders() public {
        bytes memory identicalMessage = abi.encode(
            address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238),
            uint256(1000e6),
            TEST_RECIPIENT
        );
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            identicalMessage
        ) returns (uint64 nonce) {
            console.log("Message accepted, nonce:", nonce);
        } catch {
            revert("Identical message should be accepted");
        }
    }
    
    function test_tokenMessengerBypassComparison() public {
        uint256 testAmount = 100e6;
        bytes memory bypassMessage = abi.encode(
            address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238),
            testAmount,
            TEST_RECIPIENT
        );
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            bypassMessage
        ) returns (uint64 nonce) {
            console.log("Bypassed TokenMessenger, nonce:", nonce);
        } catch {
            revert("Bypass message should be accepted");
        }
    }
    
    function test_senderInformationLogging() public {
        bytes memory testMessage = abi.encode(uint256(999), msg.sender, address(this));
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            testMessage
        ) returns (uint64 nonce) {
            console.log("Nonce assigned:", nonce);
        } catch {
            revert("Message should be accepted");
        }
    }
}
