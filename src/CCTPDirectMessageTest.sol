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
 * @dev Test harness for Iris-style cross-chain message validation tests.
 * This contract intentionally keeps the logic local so the Foundry tests can
 * exercise the intended verification behavior without requiring a live CCTP
 * deployment on forked Sepolia.
 */
contract CCTPDirectMessageTest {
    address public owner;
    uint64 private _nextNonce;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    IMessageTransmitter public messageTransmitter;
    ITokenMessenger public tokenMessenger;
    address public usdc;

    uint32 public constant ETHEREUM_DOMAIN = 0;
    uint32 public constant POLYGON_DOMAIN = 7;
    uint32 public constant AVALANCHE_DOMAIN = 1;

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

    constructor() {
        owner = msg.sender;
        _nextNonce = 1;

        // We do not depend on a live CCTP deployment in tests.
        messageTransmitter = IMessageTransmitter(address(0));
        tokenMessenger = ITokenMessenger(address(0));
        usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    }

    function _nextNonceValue() internal returns (uint64) {
        uint64 nonce = _nextNonce;
        _nextNonce += 1;
        return nonce;
    }

    function _emitMessageEvents(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata message,
        string memory messageType
    ) internal {
        uint64 nonce = _nextNonceValue();

        emit DirectMessageSent(
            nonce,
            destinationDomain,
            recipientAddress,
            message,
            messageType
        );

        emit MessageStructureLogged(
            nonce,
            message.length,
            keccak256(message),
            msg.sender
        );
    }

    function test_sendArbitraryMessage(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata arbitraryMessage
    ) external onlyOwner returns (uint64 nonce) {
        require(arbitraryMessage.length > 0, "Message cannot be empty");

        nonce = _nextNonceValue();

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

        nonce = _nextNonceValue();

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

        nonce = _nextNonceValue();

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

        nonce = _nextNonceValue();

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

    function getNextNonce() external view returns (uint64) {
        return _nextNonce;
    }
}
