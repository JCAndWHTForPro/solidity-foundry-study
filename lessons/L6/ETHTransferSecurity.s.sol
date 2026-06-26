// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./ETHTransferSecurity.sol";

/// @notice 部署脚本：部署 SecureBank 并演示安全存取
contract ETHTransferSecurityScript is Script {
    function run() external {
        vm.startBroadcast();

        // 部署安全银行合约
        SecureBank bank = new SecureBank();
        console.log("SecureBank deployed at:", address(bank));
        console.log("  owner:", bank.owner());

        // 存入 0.5 ether
        bank.deposit{value: 0.5 ether}();
        console.log("  deposited: 0.5 ether");
        console.log("  contract balance:", bank.getContractBalance());
        console.log("  total deposits:", bank.totalDeposits());

        // 取出 0.1 ether
        bank.withdraw(0.1 ether);
        console.log("  withdrew: 0.1 ether");
        console.log("  contract balance:", bank.getContractBalance());
        console.log("  total deposits:", bank.totalDeposits());

        vm.stopBroadcast();
    }
}
