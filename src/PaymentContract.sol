// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title PaymentContract
 * @dev Handles escrow and conditional payments for supply chain participants.
 * @dev Gas optimized with packed structs and efficient storage usage.
 */
contract PaymentContract is AccessControl, ReentrancyGuard, Pausable {
    error InsufficientFunds();
    error PaymentAlreadyExecuted();
    error InvalidPaymentTerms();
    error PaymentExpired();
    error PaymentNotExpired();
    error UnauthorizedCancellation();

    // Gas optimized struct packing
    struct PaymentTerms {
        address payee;          // 20 bytes - slot 0
        uint96 amount;          // 12 bytes - fits in slot 0
        address payer;          // 20 bytes - slot 1
        uint64 dueDate;         // 8 bytes - fits in slot 1
        uint8 status;           // 1 byte - fits in slot 1 (0=pending, 1=executed, 2=cancelled)
        bytes32 conditionsHash; // 32 bytes - slot 2
    }

    mapping(uint256 => PaymentTerms) public payments;
    mapping(address => uint256) public escrowBalances;
    uint256 private _paymentCounter;

    // Add payment status constants
    uint8 private constant STATUS_PENDING = 0;
    uint8 private constant STATUS_EXECUTED = 1;
    uint8 private constant STATUS_CANCELLED = 2;

    event PaymentCreated(uint256 indexed paymentId, address indexed payer, address indexed payee, uint256 amount);
    event PaymentExecuted(uint256 indexed paymentId, uint256 amount);
    event PaymentCancelled(uint256 indexed paymentId, uint256 amount);
    event FundsDeposited(address indexed depositor, uint256 amount);
    event FundsWithdrawn(address indexed withdrawer, uint256 amount);

    modifier validPayment(uint256 paymentId) {
        if (payments[paymentId].payer == address(0)) revert InvalidPaymentTerms();
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createPayment(
        uint96 amount, // Changed to uint96 for gas optimization
        address payee,
        uint64 dueDate,
        bytes32 conditionsHash
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        if (amount == 0 || payee == address(0) || payee == msg.sender) revert InvalidPaymentTerms();
        if (dueDate <= block.timestamp) revert InvalidPaymentTerms();
        
        uint256 paymentId = ++_paymentCounter;
        
        payments[paymentId] = PaymentTerms({
            amount: amount,
            payee: payee,
            payer: msg.sender,
            dueDate: dueDate,
            status: STATUS_PENDING,
            conditionsHash: conditionsHash
        });

        // Handle escrow deposit
        if (msg.value > 0) {
            escrowBalances[msg.sender] += msg.value;
            emit FundsDeposited(msg.sender, msg.value);
        }

        emit PaymentCreated(paymentId, msg.sender, payee, amount);
        return paymentId;
    }

    function executePayment(uint256 paymentId) 
        external 
        whenNotPaused 
        nonReentrant 
        validPayment(paymentId)
    {
        PaymentTerms storage payment = payments[paymentId];
        
        if (payment.status != STATUS_PENDING) revert PaymentAlreadyExecuted();
        if (block.timestamp > payment.dueDate) revert PaymentExpired();
        if (escrowBalances[payment.payer] < payment.amount) revert InsufficientFunds();
        
        // Only payer or payee can execute
        if (msg.sender != payment.payer && msg.sender != payment.payee) {
            revert InvalidPaymentTerms();
        }
        
        payment.status = STATUS_EXECUTED;
        escrowBalances[payment.payer] -= payment.amount;
        
        // Use low-level call with proper gas limits
        (bool success, ) = payable(payment.payee).call{value: payment.amount, gas: 2300}("");
        require(success, "Payment transfer failed");
        
        emit PaymentExecuted(paymentId, payment.amount);
    }

    function cancelPayment(uint256 paymentId) 
        external 
        whenNotPaused 
        nonReentrant 
        validPayment(paymentId)
    {
        PaymentTerms storage payment = payments[paymentId];
        
        if (payment.status != STATUS_PENDING) revert PaymentAlreadyExecuted();
        
        // Only payer can cancel before due date, anyone can cancel after due date
        if (block.timestamp <= payment.dueDate && msg.sender != payment.payer) {
            revert UnauthorizedCancellation();
        }
        
        payment.status = STATUS_CANCELLED;
        
        emit PaymentCancelled(paymentId, payment.amount);
    }

    function depositFunds() external payable {
        if (msg.value == 0) revert InvalidPaymentTerms();
        escrowBalances[msg.sender] += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdrawFunds(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidPaymentTerms();
        if (escrowBalances[msg.sender] < amount) revert InsufficientFunds();
        
        escrowBalances[msg.sender] -= amount;
        
        (bool success, ) = payable(msg.sender).call{value: amount, gas: 2300}("");
        require(success, "Withdrawal failed");
        
        emit FundsWithdrawn(msg.sender, amount);
    }

    // View functions
    function getPaymentStatus(uint256 paymentId) 
        external 
        view 
        validPayment(paymentId)
        returns (string memory) 
    {
        uint8 status = payments[paymentId].status;
        if (status == STATUS_PENDING) return "Pending";
        if (status == STATUS_EXECUTED) return "Executed";
        if (status == STATUS_CANCELLED) return "Cancelled";
        return "Unknown";
    }

    function isPaymentExpired(uint256 paymentId) 
        external 
        view 
        validPayment(paymentId)
        returns (bool) 
    {
        return block.timestamp > payments[paymentId].dueDate;
    }

    function getAvailableBalance(address account) external view returns (uint256) {
        return escrowBalances[account];
    }

    // Admin functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // Emergency withdrawal function for admin
    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Emergency withdrawal failed");
    }
}