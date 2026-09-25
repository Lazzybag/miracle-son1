// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CCTPDirectMessageTest.sol";

/**
 * @title IrisSignatureAnalysis
 * @dev Tests for analyzing Iris signature verification behavior
 */
contract IrisSignatureAnalysis is Test {
    CCTPDirectMessageTest public testContract;
    
    uint32 constant SEPOLIA_DOMAIN = 0;
    bytes32 constant TEST_RECIPIENT = bytes32(uint256(0x7777));
    
    function setUp() public {
        testContract = new CCTPDirectMessageTest();
    }
    
    function test_fakeUSDCDepositSigning() public {
        uint256 unauthorizedAmount = 999999e6; // 999,999 USDC (fake)
        
        try testContract.test_sendFakeUSDCDeposit(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            unauthorizedAmount
        ) returns (uint64 nonce) {
            assertGt(nonce, 0);
            console.log("Fake USDC deposit accepted, nonce:", nonce);
        } catch Error(string memory reason) {
            console.log("Fake USDC deposit rejected:", reason);
        }
    }
    
    function test_multipleMessagesNonceSequence() public {
        uint64 firstNonce;
        uint64 secondNonce;
        uint64 thirdNonce;
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            abi.encode("message1", uint256(1))
        ) returns (uint64 nonce) {
            firstNonce = nonce;
            console.log("Message 1 - Nonce:", nonce);
        } catch {
            revert("First message should be accepted");
        }
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            abi.encode("message2", uint256(2))
        ) returns (uint64 nonce) {
            secondNonce = nonce;
            console.log("Message 2 - Nonce:", nonce);
        } catch {
            revert("Second message should be accepted");
        }
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            abi.encode("message3", uint256(3))
        ) returns (uint64 nonce) {
            thirdNonce = nonce;
            console.log("Message 3 - Nonce:", nonce);
        } catch {
            revert("Third message should be accepted");
        }
        
        assertTrue(secondNonce > firstNonce, "Nonces should be sequential");
        assertTrue(thirdNonce > secondNonce, "Nonces should be sequential");
    }
    
    function test_messageHashConsistency() public {
        bytes memory message1 = abi.encode(uint256(111), "test");
        bytes memory message2 = abi.encode(uint256(111), "test");
        bytes memory message3 = abi.encode(uint256(112), "test");
        
        bytes32 hash1 = keccak256(message1);
        bytes32 hash2 = keccak256(message2);
        bytes32 hash3 = keccak256(message3);
        
        assertEq(hash1, hash2, "Identical messages should have same hash");
        assertNotEq(hash1, hash3, "Different messages should have different hash");
    }
    
    function test_signatureDeterminism() public {
        bytes memory deterministicMessage = abi.encode(
            address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238),
            uint256(1000e6),
            TEST_RECIPIENT
        );
        
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            deterministicMessage
        ) returns (uint64 nonce) {
            console.log("Message accepted, nonce:", nonce);
        } catch {
            revert("Message should be accepted");
        }
    }
    
    function test_crossDomainMessageSigning() public {
        bytes memory universalMessage = abi.encode(
            uint256(5000),
            "cross-domain",
            address(0x1234567890123456789012345678901234567890)
        );
        
        try testContract.test_sendArbitraryMessage(
            7, // Polygon domain
            TEST_RECIPIENT,
            universalMessage
        ) returns (uint64 nonce1) {
            console.log("Message to Polygon domain, nonce:", nonce1);
        } catch {
            revert("Message to Polygon should be accepted");
        }
    }
    
    function test_prepareForIrisVerification() public {
        bytes memory targetMessage = abi.encode(
            address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238),
            uint256(50000e6),
            TEST_RECIPIENT
        );
        
        uint64 nonce = 0;
        try testContract.test_sendArbitraryMessage(
            SEPOLIA_DOMAIN,
            TEST_RECIPIENT,
            targetMessage
        ) returns (uint64 returnedNonce) {
            nonce = returnedNonce;
        } catch {
            revert("Message should be accepted");
        }
        
        console.log("Iris Verification Data ready for Nonce:", nonce);
    }
}
