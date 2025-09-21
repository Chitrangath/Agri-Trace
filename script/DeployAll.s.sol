// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/AgricultureSupplyChain.sol";
import "../src/PaymentContract.sol";
import "../src/QRCodeRegistry.sol";

contract DeployAll is Script {
    function run() external returns (AgricultureSupplyChain, PaymentContract, QRCodeRegistry) {
        vm.startBroadcast();
        
        AgricultureSupplyChain supplyChain = new AgricultureSupplyChain();
        PaymentContract payment = new PaymentContract();
        QRCodeRegistry qr = new QRCodeRegistry();
        
        vm.stopBroadcast();
        
        return (supplyChain, payment, qr);
    }
}
