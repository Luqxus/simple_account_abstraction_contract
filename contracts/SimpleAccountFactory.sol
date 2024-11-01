// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./SimpleAccount.sol"; // The contract we created earlier

/**
 * @title SimpleAccountFactory
 * @dev Factory contract for deploying SimpleAccount contracts using create2
 */
contract SimpleAccountFactory {
    IEntryPoint public immutable entryPoint;
    
    // Events
    event AccountCreated(address indexed account, address indexed owner);
    event AccountDeployed(address indexed account, address indexed owner, uint256 salt);

    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
    }

    /**
     * @dev Creates an account, and returns its address.
     * Returns the address even if the account is already deployed.
     * @param owner The owner of the account
     * @param salt The salt for create2
     */
    function getAddress(address owner, uint256 salt) public view returns (address) {
        return create2Address(
            keccak256(
                abi.encodePacked(
                    type(SimpleAccount).creationCode,
                    abi.encode(entryPoint, owner)
                )
            ),
            salt
        );
    }

    /**
     * @dev Creates a new account for the given owner.
     * @param owner The owner of the account
     * @param salt A salt to determine the account address
     * @return addr The address of the created account
     */
    function createAccount(address owner, uint256 salt) public returns (SimpleAccount addr) {
        address accountAddress = getAddress(owner, salt);
        
        // If account already deployed, return its address
        uint256 codeSize = accountAddress.code.length;
        if (codeSize > 0) {
            return SimpleAccount(payable(accountAddress));
        }

        // Deploy new account
        addr = SimpleAccount(
            payable(
                new SimpleAccount{salt: bytes32(salt)}(
                    entryPoint,
                    owner
                )
            )
        );

        emit AccountCreated(address(addr), owner);
    }

    /**
     * @dev Helper function to calculate create2 address
     * @param creationCode The contract creation code
     * @param salt The salt value
     */
    function create2Address(bytes32 creationCode, uint256 salt) internal view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            creationCode
                        )
                    )
                )
            )
        );
    }

    /**
     * @dev Creates an account and funds it with ETH in one transaction
     * @param owner The owner of the account
     * @param salt A salt to determine the account address
     */
    function createAccountWithDeposit(address owner, uint256 salt) external payable returns (SimpleAccount) {
        SimpleAccount account = createAccount(owner, salt);
        
        // Forward any ETH sent to the new account
        if (msg.value > 0) {
            (bool success,) = address(account).call{value: msg.value}("");
            require(success, "Failed to send ETH to new account");
        }

        emit AccountDeployed(address(account), owner, salt);
        return account;
    }

    /**
     * @dev Batch creates multiple accounts for different owners
     * @param owners Array of account owners
     * @param salts Array of salts for each account
     */
    function batchCreateAccounts(
        address[] calldata owners,
        uint256[] calldata salts
    ) external returns (SimpleAccount[] memory accounts) {
        require(owners.length == salts.length, "Arrays length mismatch");
        
        accounts = new SimpleAccount[](owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            accounts[i] = createAccount(owners[i], salts[i]);
        }
        
        return accounts;
    }

    /**
     * @dev Allows the factory to receive ETH
     */
    receive() external payable {}
}