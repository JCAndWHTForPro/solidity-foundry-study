// SPDX-License-Identifier: MIT
// ─────────────────────────────────────────────────────────────────────────────
// 【L1 · 第 3 个文件】HelloWorld.s.sol —— 部署脚本
//
// 📚 教学讲义全部写在注释里。
//    这一节告诉学员：合约不能光在测试里跑，要"上链"才有意义。
// ─────────────────────────────────────────────────────────────────────────────

pragma solidity ^0.8.13;

// Script 是 forge-std 提供的"部署脚本"基类，
// 它内置了 vm 对象（cheatcode）、console（日志打印）等工具。
import {Script, console} from "forge-std/Script.sol";

import {HelloWorld} from "./HelloWorld.sol";


/// @title HelloWorldScript - 把 HelloWorld 部署到一条链上
/// @notice 通过 forge script 命令运行，会"模拟 + 广播"地把合约部署上去
contract HelloWorldScript is Script {
    // ─────────────────────────────────────────────────────────────────────
    // 【知识点 1】部署脚本的入口函数 run()
    //
    //   • forge script 默认会调用名叫 run() 的函数；
    //   • run() 里两个关键的 cheatcode：
    //       vm.startBroadcast()  →  从这一行起，下面所有"会改链状态"的调用，
    //                               都会被打包成真实交易广播到链上；
    //       vm.stopBroadcast()   →  停止广播。
    //   • 在 startBroadcast / stopBroadcast 之间发生的事情，才会真的被部署 / 调用。
    // ─────────────────────────────────────────────────────────────────────
    function run() external {
        vm.startBroadcast();

        // ▶ 这一行的 new HelloWorld() 会变成一笔"部署合约的交易"广播到链上。
        HelloWorld hello = new HelloWorld();

        vm.stopBroadcast();

        // console.log 是 forge-std 提供的链下日志工具，
        // 部署完会打印出合约地址，方便后续用 cast 调用。
        console.log("HelloWorld deployed at:", address(hello));
        console.log("Initial greeting:", hello.greet());
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎓 怎么使用本脚本？
//
// 1️⃣ 起一个本地链（新开终端）：
//      anvil
//    会打印出 10 个测试账户和私钥，监听 http://127.0.0.1:8545
//
// 2️⃣ 部署到本地链（在工程根目录执行）：
//      FOUNDRY_PROFILE=l1 forge script HelloWorld.s.sol:HelloWorldScript \
//        --rpc-url http://127.0.0.1:8545 \
//        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//        --broadcast
//
//    输出里会看到：
//      HelloWorld deployed at: 0x5FbDB2315678afecb367f032d93F642f64180aa3
//      Initial greeting: Hello, World
//
// 3️⃣ 用 cast 调用（把 <ADDR> 换成上一步输出的地址）：
//      cast call <ADDR> "greet()(string)" --rpc-url http://127.0.0.1:8545
//
// ─────────────────────────────────────────────────────────────────────────────
// 🧠 部署到测试网 / 主网？
//   把 --rpc-url 换成对应网络的 RPC（如 Sepolia 的 Infura/Alchemy 链接），
//   把 --private-key 换成自己钱包里有测试 ETH 的私钥。
//   注意：⚠️ 真实钱包私钥绝对不要写进代码或提交到 Git！
// ─────────────────────────────────────────────────────────────────────────────
