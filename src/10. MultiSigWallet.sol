// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract MultiSigWalletOptimized {
    address[] public owners;
    uint256 public required;

    struct Transaction {
        address destination;
        uint256 value;
        uint256 confirmationCount;
        bool executed;
    }

    Transaction[] public transactions;
    mapping(address => bool) public isOwnerMap; 
    mapping(uint256 => uint256) private confirmationsBitmap; 

    event Deposit(address indexed sender, uint256 value);
    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed owner, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);

    modifier onlyOwner() {
        require(isOwnerMap[msg.sender], "Not owner");
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(transactionId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notConfirmed(uint256 transactionId) {
        require((confirmationsBitmap[transactionId] & (1 << ownerIndex(msg.sender))) == 0, "Transaction already confirmed");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid number of required confirmations");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwnerMap[owner], "Duplicate owner");
            isOwnerMap[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address destination, uint256 value) public onlyOwner {
        transactions.push(
            Transaction({
                destination: destination,
                value: value,
                confirmationCount: 0,
                executed: false
            })
        );

        emit Submission(transactions.length - 1);
    }

    function confirmTransaction(uint256 transactionId)
        public
        onlyOwner
        transactionExists(transactionId)
        notConfirmed(transactionId)
    {
        uint256 ownerIdx = ownerIndex(msg.sender);
        confirmationsBitmap[transactionId] |= (1 << ownerIdx);

        Transaction storage txn = transactions[transactionId];
        txn.confirmationCount += 1;

        emit Confirmation(msg.sender, transactionId);

        if (txn.confirmationCount >= required && !txn.executed) {
            executeTransaction(transactionId);
        }
    }

    function executeTransaction(uint256 transactionId)
        public
        onlyOwner
        transactionExists(transactionId)
        notExecuted(transactionId)
    {
        Transaction storage txn = transactions[transactionId];
        require(txn.confirmationCount >= required, "Not enough confirmations");

        txn.executed = true;
        (bool success,) = txn.destination.call{value: txn.value}("");
        if (success) {
            emit Execution(transactionId);
        } else {
            txn.executed = false;
            emit ExecutionFailure(transactionId);
        }
    }

    function ownerIndex(address owner) internal view returns (uint256) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                return i;
            }
        }
        revert("Owner not found");
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getConfirmations(uint256 transactionId) public view returns (address[] memory) {
        uint256 count = transactions[transactionId].confirmationCount;
        address[] memory confirmations = new address[](count);
        uint256 idx = 0;

        for (uint256 i = 0; i < owners.length; i++) {
            if ((confirmationsBitmap[transactionId] & (1 << i)) != 0) {
                confirmations[idx] = owners[i];
                idx++;
            }
        }

        return confirmations;
    }
}



contract MultiSigWallet {
    address[] public owners;
    uint256 public required;

    struct Transaction {
        uint256 transactionID;
        address destination;
        uint256 value;
        uint256 confirmationCount;
        uint256 executionTimestamp;
        bool executed;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    event Deposit(address indexed sender, uint256 value);
    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed owner, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);

    modifier onlyOwner() {
        require(isOwner(msg.sender), "Not owner");
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(transactionId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notConfirmed(uint256 transactionId) {
        require(!confirmations[transactionId][msg.sender], "Transaction already confirmed");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid number of required confirmations");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            owners.push(_owners[i]);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address destination, uint256 value) public onlyOwner {
        transactions.push(
            Transaction({
                transactionID: transactions.length,
                destination: destination,
                value: value,
                confirmationCount: 0,
                executionTimestamp: 0,
                executed: false
            })
        );

        emit Submission(transactions.length);
    }

    function confirmTransaction(uint256 transactionId)
        public
        onlyOwner
        transactionExists(transactionId)
        notConfirmed(transactionId)
    {
        confirmations[transactionId][msg.sender] = true;
        transactions[transactionId].confirmationCount += 1;

        emit Confirmation(msg.sender, transactionId);

        if (transactions[transactionId].confirmationCount >= required) {
            executeTransaction(transactionId);
        }
    }

    function executeTransaction(uint256 transactionId)
        public
        onlyOwner
        transactionExists(transactionId)
        notExecuted(transactionId)
    {
        if (transactions[transactionId].confirmationCount >= required) {
            transactions[transactionId].executed = true;

            (bool success,) = transactions[transactionId].destination.call{value: transactions[transactionId].value}("");
            if (success) {
                emit Execution(transactionId);
            } else {
                transactions[transactionId].executed = false;
                emit ExecutionFailure(transactionId);
            }
        }
    }

    function isOwner(address account) public view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == account) {
                return true;
            }
        }
        return false;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getConfirmations(uint256 transactionId) public view returns (address[] memory) {
        address[] memory _confirmations = new address[](owners.length);
        uint256 count = 0;

        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                _confirmations[count] = owners[i];
                count += 1;
            }
        }

        address[] memory confirmationsTrimmed = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            confirmationsTrimmed[i] = _confirmations[i];
        }

        return confirmationsTrimmed;
    }
}
