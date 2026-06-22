// SPDX-License-Identifier: MIT
// ─────────────────────────────────────────────────────────────────────────────
// 【L2 · 部署脚本】TypesDemo.s.sol
//
// 📚 用最简单的方式把 TypesDemo 部署到链上，并打印初始状态。
// ─────────────────────────────────────────────────────────────────────────────

pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TypesDemo} from "./TypesDemo.sol";


contract TypesDemoScript is Script {
    /// forge script 默认入口
    function run() external {
        vm.startBroadcast();

        TypesDemo demo = new TypesDemo();

        // 顺便演示：脚本里也能继续调用合约（每一次调用都是一笔交易）
        demo.addUser("Alice");
        demo.addUser("Bob");

        vm.stopBroadcast();

        // 链下打印部署结果
        console.log("TypesDemo deployed at:", address(demo));
        console.log("Initial name        :", demo.name());
        console.log("User count          :", demo.userCount());
        console.log("Owner               :", demo.owner());
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎓 怎么使用本脚本？
//
// 1️⃣ 起本地链（新开终端）：
//      anvil
//
// 2️⃣ 部署（工程根目录）：
//      FOUNDRY_PROFILE=l2 forge script TypesDemo.s.sol:TypesDemoScript \
//        --rpc-url http://127.0.0.1:8545 \
//        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//        --broadcast
//
// 3️⃣ 用 cast 调用：
//      cast call <ADDR> "name()(string)"           --rpc-url http://127.0.0.1:8545
//      cast call <ADDR> "userCount()(uint256)"     --rpc-url http://127.0.0.1:8545
//      cast call <ADDR> "users(uint256)(string,uint256,bool)" 0 --rpc-url http://127.0.0.1:8545
// ─────────────────────────────────────────────────────────────────────────────
