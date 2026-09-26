// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMessageTransmitter
 * @dev Interface for Circle's MessageTransmitter contract
 */
interface IMessageTransmitter {
    function sendMessage(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes calldata messageBody
    ) external returns (uint64 nonce);

    function getNextAvailableNonce() external view returns (uint64);
}

/**
 * @title ITokenMessenger
 * @dev Interface for Circle's TokenMessenger contract
 */
interface ITokenMessenger {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 nonce);
}

/**
 * @title CCTPDirectMessageTest
 * @dev Test contract for analyzing Iris payment verification
 */
contract CCTPDirectMessageTest {
    // ============ Simple Ownership Logic ============
    address public owner;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    // ============ Core Addresses (Cleaned & Checked for EIP-55 Compliance) ============
    IMessageTransmitter public constant messageTransmitter = IMessageTransmitter(0x0EB340e74b09c2CE87AFCD8b8C156f081432f5c1);
    ITokenMessenger public constant tokenMessenger = ITokenMessenger(0x12b7546E3A678bd317f25979C6F676Be1b759604);
    address public constant usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    // Domain IDs for common chains
    uint32 public constant ETHEREUM_DOMAIN = 0;
    uint32 public constant POLYGON_DOMAIN = 7;
    uint32 public constant AVALANCHE_DOMAIN = 1;
    
    // ============ Events ============
    
    event DirectMessageSent(
        uint64 indexed nonce,
        uint32 destinationDomain,
        bytes32 recipient,
        bytes message,
        string messageType
    );
    
    event MessageStructureLogged(
        uint64 indexed nonce,
        uint256 messageLength,
        bytes32 messageHash,
        address sender
    );
    
    // ============ Constructor ============
    
    constructor() {
        owner = msg.sender;
    }
    
    // ============ Test Functions ============
    
    function test_sendArbitraryMessage(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata arbitraryMessage
    ) external onlyOwner returns (uint64 nonce) {
        require(arbitraryMessage.length > 0, "Message cannot be empty");
        
        nonce = messageTransmitter.sendMessage(
            destinationDomain,
            recipientAddress,
            arbitraryMessage
        );
        
        emit DirectMessageSent(
            nonce,
            destinationDomain,
            recipientAddress,
            arbitraryMessage,
            "arbitrary"
        );
        
        emit MessageStructureLogged(
            nonce,
            arbitraryMessage.length,
            keccak256(arbitraryMessage),
            msg.sender
        );
        
        return nonce;
    }
    
    function test_sendFakeUSDCDeposit(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        uint256 fakeAmount
    ) external onlyOwner returns (uint64 nonce) {
        bytes memory fakeDepositMessage = abi.encode(
            usdc,                
            fakeAmount,          
            recipientAddress     
        );
        
        nonce = messageTransmitter.sendMessage(
            destinationDomain,
            recipientAddress,
            fakeDepositMessage
        );
        
        emit DirectMessageSent(
            nonce,
            destinationDomain,
            recipientAddress,
            fakeDepositMessage,
            "fakeDeposit"
        );
        
        emit MessageStructureLogged(
            nonce,
            fakeDepositMessage.length,
            keccak256(fakeDepositMessage),
            msg.sender
        );
        
        return nonce;
    }
    
    function test_sendMalformedMessage(
        uint32 destinationDomain,
        bytes32 recipientAddress
    ) external onlyOwner returns (uint64 nonce) {
        bytes memory malformedMessage = abi.encodePacked(
            uint8(0),  
            recipientAddress
        );
        
        nonce = messageTransmitter.sendMessage(
            destinationDomain,
            recipientAddress,
            malformedMessage
        );
        
        emit DirectMessageSent(
            nonce,
            destinationDomain,
            recipientAddress,
            malformedMessage,
            "malformed"
        );
        
        emit MessageStructureLogged(
            nonce,
            malformedMessage.length,
            keccak256(malformedMessage),
            msg.sender
        );
        
        return nonce;
    }
    
    function test_sendNormalDeposit(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient
    ) external onlyOwner returns (uint64 nonce) {
        bytes memory expectedMessage = abi.encode(
            usdc,
            amount,
            mintRecipient
        );
        
        emit MessageStructureLogged(
            0, 
            expectedMessage.length,
            keccak256(expectedMessage),
            msg.sender
        );
        
        return 0;
    }
    
    function test_sendVaryingSizeMessages(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        uint8 payloadSize
    ) external onlyOwner returns (uint64 nonce) {
        require(payloadSize > 0 && payloadSize <= 100, "Invalid payload size");
        
        bytes memory variableMessage = new bytes(payloadSize);
        for (uint8 i = 0; i < payloadSize; i++) {
            variableMessage[i] = bytes1(uint8(i % 256));
        }
        
        nonce = messageTransmitter.sendMessage(
            destinationDomain,
            recipientAddress,
            variableMessage
        );
        
        emit DirectMessageSent(
            nonce,
            destinationDomain,
            recipientAddress,
            variableMessage,
            "variableSize"
        );
        
        emit MessageStructureLogged(
            nonce,
            variableMessage.length,
            keccak256(variableMessage),
            msg.sender
        );
        
        return nonce;
    }
    
    // ============ Helper Functions ============
    
    function getNextNonce() external view returns (uint64) {
        try messageTransmitter.getNextAvailableNonce() returns (uint64 nextNonce) {
            return nextNonce;
        } catch {
            return 0; 
        }
    }
}
