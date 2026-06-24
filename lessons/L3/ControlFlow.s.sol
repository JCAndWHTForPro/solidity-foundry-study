// SPDX-License-Identifier: MIT
// ─────────────────────────────────────────────────────────────────────────────
// 【L3 · 部署脚本】ControlFlow.s.sol
//
// 📚 把 ControlFlow 部署到链上，并演示几个典型操作。
// ─────────────────────────────────────────────────────────────────────────────

pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ControlFlow} from "./ControlFlow.sol";


contract ControlFlowScript is Script {
    /// forge script 默认入口
    function run() external {
        vm.startBroadcast();

        ControlFlow cf = new ControlFlow();

        // 演示：部署后添加几个分数
        cf.addScore(85);
        cf.addScore(92);
        cf.addScore(67);

        // 演示：递增 counter
        cf.increment();
        cf.increment();

        // 演示：把某个地址加入白名单
        address vipUser = address(0xA11CE);
        cf.addToWhitelist(vipUser);

        vm.stopBroadcast();

        // 链下打印部署结果
        console.log("ControlFlow deployed at:", address(cf));
        console.log("Owner               :", cf.owner());
        console.log("Counter             :", cf.counter());
        console.log("Scores count        :", cf.scoresLength());
        console.log("Total score         :", cf.totalScore());
        console.log("Grade for 85        :", cf.getGrade(85));
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎓 怎么使用本脚本？
//
// 1️⃣ 起本地链（新开终端）：
//      anvil
//
// 2️⃣ 部署（工程根目录）：
//      FOUNDRY_PROFILE=l3 forge script ControlFlow.s.sol:ControlFlowScript \
//        --rpc-url http://127.0.0.1:8545 \
//        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//        --broadcast
//
// 3️⃣ 用 cast 调用：
//      cast call <ADDR> "getGrade(uint256)(string)" 75 --rpc-url http://127.0.0.1:8545
//      cast call <ADDR> "counter()(uint256)"            --rpc-url http://127.0.0.1:8545
//      cast call <ADDR> "totalScore()(uint256)"         --rpc-url http://127.0.0.1:8545
// ─────────────────────────────────────────────────────────────────────────────
