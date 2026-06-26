// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./EventsAndETH.sol";

/// @notice 部署脚本：部署 EventsAndETH 合约并演示基本操作
contract EventsAndETHScript is Script {
    function run() external {
        vm.startBroadcast();

        // 1. 部署合约
        EventsAndETH vault = new EventsAndETH();
        console.log("EventsAndETH deployed at:", address(vault));
        console.log("  owner:", vault.owner());

        // 2. 存款
        vault.deposit{value: 0.01 ether}();
        console.log("  deposited: 0.01 ether");
        console.log("  contract balance:", vault.getContractBalance());

        // 3. 查询 ETH 单位
        (uint256 oneWei, uint256 oneGwei, uint256 oneEther) = vault.ethUnits();
        console.log("  1 wei =", oneWei);
        console.log("  1 gwei =", oneGwei);
        console.log("  1 ether =", oneEther);

        vm.stopBroadcast();
    }
}
