// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/PaymentContract.sol";

contract PaymentContractTest is Test {
    PaymentContract payment;
    address payer = address(0x1);
    address payee = address(0x2);
    address admin;

    function setUp() public {
        admin = address(this);
        payment = new PaymentContract();
        vm.deal(payer, 10 ether);
        vm.deal(payee, 1 ether);
    }

    function testCreateAndExecutePayment() public {
        vm.startPrank(payer);
        uint256 id = payment.createPayment{value: 2 ether}(
            2 ether, 
            payee, 
            uint64(block.timestamp + 1 days), 
            bytes32(0)
        );
        
        payment.executePayment(id);
        vm.stopPrank();

        assertEq(payee.balance, 3 ether); // 1 ether initial + 2 ether payment
        assertEq(payment.getPaymentStatus(id), "Executed");
    }

    function testDepositAndWithdraw() public {
        vm.startPrank(payer);
        payment.depositFunds{value: 1 ether}();
        assertEq(payment.getAvailableBalance(payer), 1 ether);
        
        payment.withdrawFunds(0.5 ether);
        assertEq(payment.getAvailableBalance(payer), 0.5 ether);
        vm.stopPrank();
    }

    function testCancelPayment() public {
        vm.startPrank(payer);
        uint256 id = payment.createPayment{value: 1 ether}(
            0.5 ether, 
            payee, 
            uint64(block.timestamp + 1 days), 
            bytes32(0)
        );
        
        payment.cancelPayment(id);
        vm.stopPrank();
        
        assertEq(payment.getPaymentStatus(id), "Cancelled");
    }

    function testCancelExpiredPayment() public {
        vm.startPrank(payer);
        uint256 id = payment.createPayment{value: 1 ether}(
            0.5 ether, 
            payee, 
            uint64(block.timestamp + 1 days), 
            bytes32(0)
        );
        vm.stopPrank();
        
        // Move time forward past due date
        vm.warp(block.timestamp + 2 days);
        
        // Anyone can cancel expired payment
        vm.prank(payee);
        payment.cancelPayment(id);
        
        assertEq(payment.getPaymentStatus(id), "Cancelled");
    }

    function testPaymentExpiry() public {
        vm.startPrank(payer);
        uint256 id = payment.createPayment{value: 1 ether}(
            0.5 ether, 
            payee, 
            uint64(block.timestamp + 1 days), 
            bytes32(0)
        );
        vm.stopPrank();
        
        // Move time forward past due date
        vm.warp(block.timestamp + 2 days);
        
        assertTrue(payment.isPaymentExpired(id));
        
        // Should revert when trying to execute expired payment
        vm.prank(payer);
        vm.expectRevert();
        payment.executePayment(id);
    }

    function testPayeeCanExecutePayment() public {
        vm.startPrank(payer);
        uint256 id = payment.createPayment{value: 2 ether}(
            1 ether, 
            payee, 
            uint64(block.timestamp + 1 days), 
            bytes32(0)
        );
        vm.stopPrank();
        
        // Payee can also execute the payment
        vm.prank(payee);
        payment.executePayment(id);
        
        assertEq(payee.balance, 2 ether); // 1 ether initial + 1 ether payment
    }

    function testFailInsufficientFunds() public {
        vm.prank(payer);
        uint256 id = payment.createPayment(100 ether, payee, uint64(block.timestamp + 1 days), bytes32(0));
        
        vm.prank(payer);
        payment.executePayment(id);
    }

    function testFailCreatePaymentWithZeroAmount() public {
        vm.prank(payer);
        payment.createPayment{value: 1 ether}(0, payee, uint64(block.timestamp + 1 days), bytes32(0));
    }

    function testFailCreatePaymentWithZeroAddress() public {
        vm.prank(payer);
        payment.createPayment{value: 1 ether}(1 ether, address(0), uint64(block.timestamp + 1 days), bytes32(0));
    }

    function testFailCreatePaymentToSelf() public {
        vm.prank(payer);
        payment.createPayment{value: 1 ether}(1 ether, payer, uint64(block.timestamp + 1 days), bytes32(0));
    }

    function testFailCreatePaymentWithPastDueDate() public {
        vm.prank(payer);
        payment.createPayment{value: 1 ether}(1 ether, payee, uint64(block.timestamp - 1 days), bytes32(0));
    }

    function testFailDoubleExecution() public {
        vm.startPrank(payer);
        uint256 id = payment.createPayment{value: 2 ether}(1 ether, payee, uint64(block.timestamp + 1 days), bytes32(0));
        payment.executePayment(id);
        payment.executePayment(id); // Should fail
        vm.stopPrank();
    }

    function testFailUnauthorizedCancellation() public {
        vm.prank(payer);
        uint256 id = payment.createPayment{value: 1 ether}(0.5 ether, payee, uint64(block.timestamp + 1 days), bytes32(0));
        
        // Random address trying to cancel before expiry should fail
        vm.prank(address(0x3));
        payment.cancelPayment(id);
    }

    function testFailWithdrawMoreThanBalance() public {
        vm.startPrank(payer);
        payment.depositFunds{value: 1 ether}();
        payment.withdrawFunds(2 ether);
        vm.stopPrank();
    }

    function testFailDepositZeroFunds() public {
        vm.prank(payer);
        payment.depositFunds{value: 0}();
    }

    function testFailWithdrawZeroAmount() public {
        vm.startPrank(payer);
        payment.depositFunds{value: 1 ether}();
        payment.withdrawFunds(0);
        vm.stopPrank();
    }

    function testPauseUnpause() public {
        payment.pause();
        
        vm.prank(payer);
        vm.expectRevert("Pausable: paused");
        payment.createPayment{value: 1 ether}(0.5 ether, payee, uint64(block.timestamp + 1 days), bytes32(0));
        
        payment.unpause();
        
        vm.prank(payer);
        uint256 id = payment.createPayment{value: 1 ether}(0.5 ether, payee, uint64(block.timestamp + 1 days), bytes32(0));
        assertGt(id, 0);
    }

    function testEmergencyWithdraw() public {
        // Add some funds to contract
        vm.prank(payer);
        payment.depositFunds{value: 5 ether}();
        
        uint256 initialBalance = admin.balance;
        uint256 contractBalance = address(payment).balance;
        
        // Admin emergency withdraw
        payment.emergencyWithdraw();
        
        assertEq(admin.balance, initialBalance + contractBalance);
        assertEq(address(payment).balance, 0);
    }

    function testMultiplePayments() public {
        vm.startPrank(payer);
        
        // Create multiple payments
        uint256 id1 = payment.createPayment{value: 3 ether}(1 ether, payee, uint64(block.timestamp + 1 days), bytes32("condition1"));
        uint256 id2 = payment.createPayment(1 ether, payee, uint64(block.timestamp + 2 days), bytes32("condition2"));
        uint256 id3 = payment.createPayment(1 ether, payee, uint64(block.timestamp + 3 days), bytes32("condition3"));
        
        // Execute first payment
        payment.executePayment(id1);
        
        // Cancel second payment
        payment.cancelPayment(id2);
        
        vm.stopPrank();
        
        // Check statuses
        assertEq(payment.getPaymentStatus(id1), "Executed");
        assertEq(payment.getPaymentStatus(id2), "Cancelled");
        assertEq(payment.getPaymentStatus(id3), "Pending");
        
        // Check balances
        assertEq(payee.balance, 2 ether); // 1 initial + 1 from payment
        assertEq(payment.getAvailableBalance(payer), 2 ether); // 3 deposited - 1 executed
    }
}