// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Core ERC-4337 interfaces
interface IEntryPoint {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}

// Simple struct to represent a UserOperation
struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

/**
 * @title SimpleAccount
 * @dev A basic smart contract wallet with account abstraction support
 */
contract SimpleAccount {
    address public owner;
    IEntryPoint private immutable entryPoint;
    uint256 private nonce;

    // Events
    event SimpleAccountInitialized(IEntryPoint indexed entryPoint, address indexed owner);
    event TransactionExecuted(address indexed target, uint256 value, bytes data);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyEntryPoint() {
        require(msg.sender == address(entryPoint), "Only EntryPoint");
        _;
    }

    constructor(IEntryPoint _entryPoint, address _owner) {
        entryPoint = _entryPoint;
        owner = _owner;
        emit SimpleAccountInitialized(_entryPoint, _owner);
    }

    /**
     * @dev Validates the user operation
     * @param userOp The user operation to validate
     * @param userOpHash The hash of the user operation
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyEntryPoint returns (uint256) {
        // Verify the signature
        bytes32 hash = keccak256(abi.encodePacked(userOpHash));
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        
        // Recover signer from signature
        bytes memory signature = userOp.signature;
        require(signature.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        address recovered = ecrecover(messageHash, v, r, s);
        require(recovered == owner, "Invalid signature");

        // Handle missing funds if needed
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds}("");
            require(success, "Failed to pay missing funds");
        }

        return 0; // Validation successful
    }

    /**
     * @dev Executes a transaction
     * @param target The target address
     * @param value The amount of ETH to send
     * @param data The calldata
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyEntryPoint returns (bool) {
        (bool success, ) = target.call{value: value}(data);
        require(success, "Transaction failed");
        emit TransactionExecuted(target, value, data);
        return success;
    }

    /**
     * @dev Returns the current nonce
     */
    function getNonce() public view returns (uint256) {
        return nonce;
    }

    /**
     * @dev Allows the account to receive ETH
     */
    receive() external payable {}
}