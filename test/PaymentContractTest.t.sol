// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/PaymentContract.sol";

contract PaymentContractTest is Test {
    PaymentContract payment;
    address payer = address(0x1);
    address payee = address(0x2);

    function setUp() public {
        payment = new PaymentContract();
        vm.deal(payer, 10 ether);
    }

    function testCreateAndExecutePayment() public {
        vm.startPrank(payer);
        uint256 id = payment.createPayment{value: 2 ether}(2 ether, payee, uint64(block.timestamp + 1 days), bytes32(0));
        payment.executePayment(id);
        vm.stopPrank();

        assertEq(payee.balance, 2 ether);
    }

    function testDepositAndWithdraw() public {
        vm.startPrank(payer);
        payment.depositFunds{value: 1 ether}();
        payment.withdrawFunds(1 ether);
        vm.stopPrank();
        assertEq(address(payment).balance, 0);
    }

    function testFail_InsufficientFunds() public {
        vm.prank(payer);
        payment.createPayment(100 ether, payee, uint64(block.timestamp + 1 days), bytes32(0));
    }
}
