// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMessageTransmitter
 * @dev Interface for Circle's MessageTransmitter contract on Sepolia
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
 * @dev Interface for Circle's TokenMessenger contract on Sepolia
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
 * @title CCTPMessageTest
 * @dev Live contract for CCTP Message Validation Research on Sepolia
 * Tests whether Iris signs arbitrary messages from unauthorized senders
 */
contract CCTPMessageTest {
    address public owner;
    address public messageTransmitterAddress;
    address public tokenMessengerAddress;
    address public usdcAddress;

    uint32 public constant ETHEREUM_DOMAIN = 0;
    uint32 public constant POLYGON_DOMAIN = 7;
    uint32 public constant AVALANCHE_DOMAIN = 1;
    uint32 public constant OPTIMISM_DOMAIN = 2;
    uint32 public constant ARBITRUM_DOMAIN = 3;

    // Events to track message sending
    event DirectMessageSent(
        uint64 indexed nonce,
        uint32 destinationDomain,
        bytes32 recipient,
        bytes message,
        bytes32 messageHash,
        address indexed sender,
        uint256 timestamp
    );

    event FakeUSDCDepositSent(
        uint64 indexed nonce,
        uint32 destinationDomain,
        bytes32 recipient,
        uint256 amount,
        bytes32 messageHash,
        address indexed sender,
        uint256 timestamp
    );

    event UnauthorizedSenderAttempt(
        address indexed sender,
        uint32 destinationDomain,
        string reason,
        uint256 timestamp
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    constructor(
        address _messageTransmitter,
        address _tokenMessenger,
        address _usdc
    ) {
        owner = msg.sender;
        messageTransmitterAddress = _messageTransmitter;
        tokenMessengerAddress = _tokenMessenger;
        usdcAddress = _usdc;
    }

    /**
     * @dev Send an arbitrary direct message through Circle's MessageTransmitter
     * @param destinationDomain The destination chain domain ID
     * @param recipientAddress The recipient address as bytes32
     * @param messageBody The arbitrary message payload
     */
    function sendDirectMessage(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external onlyOwner returns (uint64 nonce) {
        require(messageBody.length > 0, "Message cannot be empty");
        require(messageTransmitterAddress != address(0), "MessageTransmitter not set");

        IMessageTransmitter transmitter = IMessageTransmitter(messageTransmitterAddress);

        nonce = transmitter.sendMessage(
            destinationDomain,
            recipientAddress,
            messageBody
        );

        bytes32 messageHash = keccak256(messageBody);

        emit DirectMessageSent(
            nonce,
            destinationDomain,
            recipientAddress,
            messageBody,
            messageHash,
            msg.sender,
            block.timestamp
        );

        return nonce;
    }

    /**
     * @dev Send a fake USDC deposit message to test Iris attestation behavior
     * @param destinationDomain The destination chain domain ID
     * @param recipientAddress The recipient address as bytes32
     * @param fakeAmount The fake USDC amount
     */
    function sendFakeUSDCDeposit(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        uint256 fakeAmount
    ) external onlyOwner returns (uint64 nonce) {
        require(messageTransmitterAddress != address(0), "MessageTransmitter not set");
        require(fakeAmount > 0, "Amount must be greater than 0");

        // Encode the fake deposit message
        bytes memory fakeDepositMessage = abi.encode(
            usdcAddress,
            fakeAmount,
            recipientAddress
        );

        IMessageTransmitter transmitter = IMessageTransmitter(messageTransmitterAddress);

        nonce = transmitter.sendMessage(
            destinationDomain,
            recipientAddress,
            fakeDepositMessage
        );

        bytes32 messageHash = keccak256(fakeDepositMessage);

        emit FakeUSDCDepositSent(
            nonce,
            destinationDomain,
            recipientAddress,
            fakeAmount,
            messageHash,
            msg.sender,
            block.timestamp
        );

        return nonce;
    }

    /**
     * @dev Send a malformed message to test Iris rejection behavior
     * @param destinationDomain The destination chain domain ID
     * @param recipientAddress The recipient address as bytes32
     */
    function sendMalformedMessage(
        uint32 destinationDomain,
        bytes32 recipientAddress
    ) external onlyOwner returns (uint64 nonce) {
        require(messageTransmitterAddress != address(0), "MessageTransmitter not set");

        // Intentionally malformed message
        bytes memory malformedMessage = abi.encodePacked(
            uint8(0),
            recipientAddress
        );

        IMessageTransmitter transmitter = IMessageTransmitter(messageTransmitterAddress);

        nonce = transmitter.sendMessage(
            destinationDomain,
            recipientAddress,
            malformedMessage
        );

        bytes32 messageHash = keccak256(malformedMessage);

        emit DirectMessageSent(
            nonce,
            destinationDomain,
            recipientAddress,
            malformedMessage,
            messageHash,
            msg.sender,
            block.timestamp
        );

        return nonce;
    }

    /**
     * @dev Attempt to send a message from an unauthorized sender
     * This should be rejected, but we test if Iris still signs it
     */
    function attemptUnauthorizedSend(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external returns (string memory) {
        if (msg.sender == owner) {
            revert("This function is for unauthorized senders only");
        }

        try this.sendDirectMessage(destinationDomain, recipientAddress, messageBody) {
            return "ERROR: Unauthorized sender was accepted!";
        } catch Error(string memory reason) {
            emit UnauthorizedSenderAttempt(
                msg.sender,
                destinationDomain,
                reason,
                block.timestamp
            );
            return reason;
        }
    }

    /**
     * @dev Get the next available nonce from MessageTransmitter
     */
    function getNextNonce() external view returns (uint64) {
        require(messageTransmitterAddress != address(0), "MessageTransmitter not set");
        IMessageTransmitter transmitter = IMessageTransmitter(messageTransmitterAddress);
        return transmitter.getNextAvailableNonce();
    }

    /**
     * @dev Update the MessageTransmitter address (owner only)
     */
    function setMessageTransmitter(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Invalid address");
        messageTransmitterAddress = newAddress;
    }

    /**
     * @dev Update the TokenMessenger address (owner only)
     */
    function setTokenMessenger(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Invalid address");
        tokenMessengerAddress = newAddress;
    }

    /**
     * @dev Update the USDC address (owner only)
     */
    function setUSDC(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Invalid address");
        usdcAddress = newAddress;
    }
}
