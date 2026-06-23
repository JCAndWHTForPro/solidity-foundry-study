// SPDX-License-Identifier: MIT
// ─────────────────────────────────────────────────────────────────────────────
// 【L1 · 第 2 个文件】HelloWorld.t.sol —— 给 HelloWorld 写测试
//
// 📚 教学讲义全部写在注释里。
//    讲师可逐段念给学员，让他们理解「为什么要写测试」+「怎么写测试」。
//
// ❓ 常见问题：这个测试文件（.t.sol）能部署到链上吗？
//
//   技术上：可以编译，也"能"部署，但【绝对不应该】部署到主网或生产环境。
//
//   原因如下：
//   1. 测试合约继承了 forge-std/Test.sol，而 Test.sol 内部依赖大量
//      Foundry 专属的 cheatcode（如 vm.prank / vm.expectEmit 等）。
//      这些 cheatcode 本质是通过一个特殊地址
//      0x7109709ECfa91a80626fF3989D68f67F5b1DD12d（Vm 接口）调用的，
//      该地址只在 Foundry 的沙盒 EVM 里存在，主网上根本没有对应合约，
//      调用会直接 revert 或静默失败。
//
//   2. 测试合约本身没有任何业务价值，部署只会浪费 gas。
//
//   3. 安全风险：测试合约往往包含特权操作（如随意伪造 msg.sender），
//      若意外部署，可能被攻击者利用。
//
//   ✅ 结论：.t.sol 文件仅/CI 测试使用，永远不要部署到链上。供本地
// ─────────────────────────────────────────────────────────────────────────────

pragma solidity ^0.8.13;

// ▶ import 语法：
//    Solidity 没有"包"概念，每个文件需要显式 import。
//    "forge-std/Test.sol" 实际指向 lib/forge-std/src/Test.sol，
//    这是 Foundry 官方测试基础库，提供 assertEq / vm.* / expectEmit 等工具。
import {Test} from "forge-std/Test.sol";

// 引入我们自己写的合约（相对当前 .t.sol 文件的路径）
import {HelloWorld} from "./HelloWorld.sol";


/// @title HelloWorldTest - 给 HelloWorld 合约写单元测试
/// @notice 演示 Foundry 测试的"4 件套"：setUp / test_xxx / assertEq / vm.*
contract HelloWorldTest is Test {
    // ─────────────────────────────────────────────────────────────────────
    // 【知识点 1】测试合约的结构
    //
    //   • 测试文件命名约定：xxx.t.sol（带 .t.）
    //   • 测试合约必须继承 forge-std 的 Test
    //   • 函数名以 test_ 开头 → 普通测试用例
    //   • 函数名以 testFuzz_ 开头 → 模糊测试（Foundry 自动生成随机入参）
    //   • 函数名以 testFail_ 开头 → 期望失败的测试（不推荐，建议用 vm.expectRevert）
    // ─────────────────────────────────────────────────────────────────────

    // 被测合约实例。注意它是 storage 状态变量，会保存在测试合约的 storage 里。
    HelloWorld internal hello;


    // ─────────────────────────────────────────────────────────────────────
    // 【知识点 2】setUp() —— 每个测试用例执行前都会先跑一次
    //
    //   作用：把测试环境"重置"成干净状态，
    //   保证测试用例之间彼此独立（不会因为前一个用例的结果影响后一个）。
    // ─────────────────────────────────────────────────────────────────────
    function setUp() public {
        hello = new HelloWorld();
        // 上一行干了什么？
        // ▶ new HelloWorld() 在测试环境里"部署"了一份 HelloWorld 合约；
        // ▶ Foundry 的测试是在一个内置的"沙盒 EVM"里跑，不需要 anvil；
        // ▶ 每个 test_ 函数跑之前 setUp 都会重新跑一遍，所以 hello 永远是全新的。
    }


    // ─────────────────────────────────────────────────────────────────────
    // 【测试用例 1】初始问候语应该是 "Hello, World"
    // ─────────────────────────────────────────────────────────────────────
    function test_DefaultGreeting() public view {
        // assertEq 是 forge-std/Test.sol 提供的断言：
        //   左边 = 实际值，右边 = 期望值；不相等就让用例失败。
        assertEq(hello.greet(), "Hello, linghuan");
    }


    // ─────────────────────────────────────────────────────────────────────
    // 【测试用例 2】setGreeting 后应该能读到新值
    // ─────────────────────────────────────────────────────────────────────
    function test_SetGreeting() public {
        hello.setGreeting("Hi Solidity");
        assertEq(hello.greet(), "Hi Solidity");
    }


    // ─────────────────────────────────────────────────────────────────────
    // 【测试用例 3】sayHi 是 pure 函数，演示纯函数测试
    // ─────────────────────────────────────────────────────────────────────
    function test_SayHi() public view {
        assertEq(hello.sayHi("Solidity"), "Hi, Solidity");
    }


    // ─────────────────────────────────────────────────────────────────────
    // 【测试用例 4】演示 cheatcode：vm.prank —— 模拟"用某个地址来调用"
    //
    //   • cheatcode 是 Foundry 提供的"作弊代码"，可以在测试里：
    //       - 伪造 msg.sender（vm.prank）
    //       - 给某个地址凭空发 ETH（vm.deal）
    //       - 跳过时间（vm.warp）
    //       - 期望调用 revert（vm.expectRevert）
    //       - 期望某个事件被触发（vm.expectEmit）
    //   • 这些都是测试专用，部署到主网时不存在。
    // ─────────────────────────────────────────────────────────────────────
    function test_SetGreetingByOtherUser() public {
        // 制造一个伪地址（任何 address 字面量都可以）
        address alice = address(0xA11CE);

        // 接下来"下一次"对外调用，msg.sender 会变成 alice
        vm.prank(alice);
        hello.setGreeting("Hi from Alice");

        assertEq(hello.greet(), "Hi from Alice");
    }


    // ─────────────────────────────────────────────────────────────────────
    // 【测试用例 5】事件测试：vm.expectEmit
    //
    //   • 四个 bool 参数依次表示：是否检查 topic1 / topic2 / topic3 / data；
    //   • HelloWorld 的事件 GreetingChanged(address indexed by, string newGreeting)：
    //       topic1 = by（因为它是 indexed），data = newGreeting
    //     所以我们检查 topic1 + data，写成 (true, false, false, true)。
    // ─────────────────────────────────────────────────────────────────────
    function test_EmitGreetingChanged() public {
        address bob = address(0xB0B);

        // 1. 先声明"下一次调用，我期待会 emit 出这样一条事件"
        vm.expectEmit(true, false, false, true);
        emit HelloWorld.GreetingChanged(bob, "Hi from Bob");

        // 2. 然后真正去触发那次调用
        vm.prank(bob);
        hello.setGreeting("Hi from Bob");
        // 如果实际触发的事件和上面声明的不一致，测试会失败。
    }


    // ─────────────────────────────────────────────────────────────────────
    // 【测试用例 6】模糊测试 Fuzz —— Foundry 自动给你随机生成入参跑 256 次
    //
    //   把 newGreeting 当作"任意输入"，验证：写进去什么，读出来就是什么。
    // ─────────────────────────────────────────────────────────────────────
    function testFuzz_SetGreeting(string calldata newGreeting) public {
        hello.setGreeting(newGreeting);
        assertEq(hello.greet(), newGreeting);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎓 学完本文件你掌握了什么？
//   1. Foundry 测试文件的结构（继承 Test、setUp、test_xxx）
//   2. assertEq 断言
//   3. cheatcode 的概念，并实际用过 vm.prank / vm.expectEmit
//   4. 模糊测试 testFuzz_ 的写法
//
// 跑命令（在工程根目录）：
//   FOUNDRY_PROFILE=l1 forge test -vv
// ─────────────────────────────────────────────────────────────────────────────
