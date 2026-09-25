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

    // ============ Dynamic Address Variables ============
    IMessageTransmitter public messageTransmitter;
    ITokenMessenger public tokenMessenger;
    address public usdc;
    
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
        
        // Direct string parsing safely avoids any EIP-55 casing compiler crashes
        messageTransmitter = IMessageTransmitter(parseAddr("0x0eb340e74b09c2ce87afcd8b8c156f081432f5c1"));
        tokenMessenger = ITokenMessenger(parseAddr("0x12b7546e3a678bd317f25979c6f676be1b759604"));
        usdc = parseAddr("0x1c7d4b196cb0c7b01d743fbc6116a902379c7238");
    }
    
    // ============ Internal Pure String Parser ============
    function parseAddr(string memory _a) internal pure returns (address _parsedAddress) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint256 i = 2; i < 42; i++) {
            b1 = uint160(uint8(tmp[i]));
            if (b1 >= 97 && b1 <= 102) {
                b1 -= 87;
            } else if (b1 >= 65 && b1 <= 70) {
                b1 -= 55;
            } else if (b1 >= 48 && b1 <= 57) {
                b1 -= 48;
            }
            iaddr = (iaddr / 16) + (b1 * 16**38);
        }
        return address(iaddr);
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
