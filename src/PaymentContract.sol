// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from"@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title PaymentContract
 * @dev Handles escrow and conditional payments for supply chain participants.
 */
contract PaymentContract is AccessControl, ReentrancyGuard, Pausable {
    error InsufficientFunds();
    error PaymentAlreadyExecuted();
    error InvalidPaymentTerms();

    struct PaymentTerms {
        uint256 amount;
        address payee;
        address payer;
        uint64 dueDate;
        bool executed;
        bytes32 conditionsHash;
    }

    mapping(uint256 => PaymentTerms) public payments;
    mapping(address => uint256) public escrowBalances;
    uint256 private _paymentCounter;

    event PaymentCreated(uint256 indexed paymentId, address indexed payer, address indexed payee, uint256 amount);
    event PaymentExecuted(uint256 indexed paymentId, uint256 amount);
    event FundsDeposited(address indexed depositor, uint256 amount);
    event FundsWithdrawn(address indexed withdrawer, uint256 amount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createPayment(
        uint256 amount,
        address payee,
        uint64 dueDate,
        bytes32 conditionsHash
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        if (amount == 0 || payee == address(0)) revert InvalidPaymentTerms();
        uint256 paymentId = ++_paymentCounter;
        payments[paymentId] = PaymentTerms({
            amount: amount,
            payee: payee,
            payer: msg.sender,
            dueDate: dueDate,
            executed: false,
            conditionsHash: conditionsHash
        });
        if (msg.value > 0) {
            escrowBalances[msg.sender] += msg.value;
            emit FundsDeposited(msg.sender, msg.value);
        }
        emit PaymentCreated(paymentId, msg.sender, payee, amount);
        return paymentId;
    }

    function executePayment(uint256 paymentId) external whenNotPaused nonReentrant {
        PaymentTerms storage payment = payments[paymentId];
        if (payment.executed) revert PaymentAlreadyExecuted();
        if (escrowBalances[payment.payer] < payment.amount) revert InsufficientFunds();
        payment.executed = true;
        escrowBalances[payment.payer] -= payment.amount;
        (bool success, ) = payable(payment.payee).call{value: payment.amount}("");
        require(success, "Payment transfer failed");
        emit PaymentExecuted(paymentId, payment.amount);
    }

    function depositFunds() external payable {
        escrowBalances[msg.sender] += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdrawFunds(uint256 amount) external nonReentrant {
        if (escrowBalances[msg.sender] < amount) revert InsufficientFunds();
        escrowBalances[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
        emit FundsWithdrawn(msg.sender, amount);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
