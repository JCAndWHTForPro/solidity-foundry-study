// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./LibraryAdvanced.sol";

/// @title L7 部署脚本
contract LibraryAdvancedScript is Script {
    function run() external {
        vm.startBroadcast();

        // 1. 部署主合约
        LibraryDemo demo = new LibraryDemo();
        console.log("LibraryDemo deployed at:", address(demo));

        // 2. 部署 Divider（供 TryCatchDemo 使用）
        Divider divider = new Divider();
        console.log("Divider deployed at:", address(divider));

        // 3. 部署 TryCatchDemo
        TryCatchDemo tryCatchDemo = new TryCatchDemo(address(divider));
        console.log("TryCatchDemo deployed at:", address(tryCatchDemo));

        vm.stopBroadcast();
    }
}
