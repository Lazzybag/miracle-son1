// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMessageTransmitter
 * @dev Minimal interface used by the local test harness.
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
 * @dev Minimal interface used by the local test harness.
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
 * @dev Local test harness used by Foundry tests. The methods here intentionally
 * mirror the names the tests expect, but they are not public Foundry fuzz tests.
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

        messageTransmitter = IMessageTransmitter(address(0));
        tokenMessenger = ITokenMessenger(address(0));
        usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    }

    function _nextNonceValue() internal returns (uint64) {
        uint64 nonce = _nextNonce;
        _nextNonce += 1;
        return nonce;
    }

    function sendArbitraryMessage(
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

    function sendFakeUSDCDeposit(
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

    function sendMalformedMessage(
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

    function sendNormalDeposit(
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

    function sendVaryingSizeMessages(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        uint8 payloadSize
    ) external onlyOwner returns (uint64 nonce) {
        require(payloadSize > 0, "Invalid payload size");

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
