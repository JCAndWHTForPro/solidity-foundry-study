// SPDX-License-Identifier: MIT
// ─────────────────────────────────────────────────────────────────────────────
// 【L2 · 测试文件】TypesDemo.t.sol —— 用测试验证类型系统的关键行为
//
// 📚 讲义全部写在注释里。这一节最关键的目标是：让学员用「测试」的方式，
//    亲眼看见 storage / memory 拷贝的区别、默认值是什么、mapping 的特性。
// ─────────────────────────────────────────────────────────────────────────────

pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TypesDemo} from "./TypesDemo.sol";


contract TypesDemoTest is Test {
    TypesDemo internal demo;

    function setUp() public {
        demo = new TypesDemo();
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 1】构造函数把状态变量正确初始化了
    // ═════════════════════════════════════════════════════════════════════
    function test_ConstructorInitialized() public view {
        assertEq(demo.flag(), true);
        assertEq(demo.smallNumber(), 42);
        assertEq(demo.signedNumber(), -100);
        assertEq(demo.name(), "Solidity");
        // owner 应该是部署者（也就是测试合约自己）
        assertEq(demo.owner(), address(this));
        // enum 比较：需要把 enum 强转成 uint8
        assertEq(uint8(demo.status()), uint8(TypesDemo.Status.Active));
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 2】mapping 默认值：没存过的 key 一定返回 0
    //
    // 这条测试要让学员明白：mapping 不是"key 不存在就报错"，
    // 而是任何 key 都能读，没存过就返回 value 类型的默认值。
    // ═════════════════════════════════════════════════════════════════════
    function test_MappingDefaultZero() public view {
        address random = address(0xDEAD);
        assertEq(demo.balanceOf(random), 0);   // 从没存过，默认 0
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 3】payable + deposit：用 vm.deal 给地址凭空发 ETH
    // ═════════════════════════════════════════════════════════════════════
    function test_Deposit() public {
        address alice = address(0xA11CE);
        vm.deal(alice, 10 ether);              // 给 alice 凭空充 10 个 ETH

        vm.prank(alice);
        demo.deposit{value: 1 ether}();        // 调用时附带 1 ETH

        assertEq(demo.balanceOf(alice), 1 ether);
        // 合约本身收到了 1 ETH
        assertEq(address(demo).balance, 1 ether);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 4】calldata 入参 + storage 拷贝
    //
    // setNumbers 把外部传入的 uint256[] 拷贝到 storage 数组里，
    // 之后通过 public 自动 getter numbers(index) 读出来。
    // ═════════════════════════════════════════════════════════════════════
    function test_SetNumbers() public {
        uint256[] memory input = new uint256[](3);
        input[0] = 10;
        input[1] = 20;
        input[2] = 30;

        demo.setNumbers(input);

        assertEq(demo.numbers(0), 10);
        assertEq(demo.numbers(1), 20);
        assertEq(demo.numbers(2), 30);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 5】pure 函数 + memory 返回值
    //
    // buildSquaredArray(5) 应该返回 [0, 1, 4, 9, 16]
    // ═════════════════════════════════════════════════════════════════════
    function test_BuildSquaredArray() public view {
        uint256[] memory r = demo.buildSquaredArray(5);
        assertEq(r.length, 5);
        assertEq(r[0], 0);
        assertEq(r[1], 1);
        assertEq(r[2], 4);
        assertEq(r[3], 9);
        assertEq(r[4], 16);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 6】storage 指针 vs memory 拷贝 —— L2 最重要的一节
    //
    // ① incrementFirstUserScore       → 拿 storage 指针改，真改了链上
    // ② tryIncrementFirstUserScoreInMemory → 拿 memory 副本改，链上没变
    // ═════════════════════════════════════════════════════════════════════
    function test_StorageVsMemory() public {
        demo.addUser("Alice");                 // users[0] = Alice, score = 0

        // —— ① 用 storage 指针：会真改 ——
        demo.incrementFirstUserScore();
        // 从 public 自动 getter 读出 users[0] 的字段（struct 解构）
        (, uint256 scoreAfterStorage, ) = demo.users(0);
        assertEq(scoreAfterStorage, 1);        // 真的变成 1 了 ✅

        // —— ② 用 memory 副本：以为改了，其实没改 ——
        uint256 returned = demo.tryIncrementFirstUserScoreInMemory();
        assertEq(returned, 2);                 // 函数返回的"内存副本"是 2

        (, uint256 scoreAfterMemory, ) = demo.users(0);
        assertEq(scoreAfterMemory, 1);         // 但链上还是 1！没变！
        // 🎯 这就是新手最容易踩的坑：以为改了 state，其实只改了 memory 副本。
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 7】可见性边界：private/internal 不能从外部调
    //
    // 这里没法直接测"调不到"（编译就过不去），所以我们换个角度：
    // 验证 doubleIt(externl 暴露的) 能正常工作。
    // ═════════════════════════════════════════════════════════════════════
    function test_DoubleIt() public view {
        assertEq(demo.doubleIt(7), 14);
    }

    function test_IsCallerOwner() public {
        // 部署 demo 的就是测试合约本身，所以 owner == address(this)
        assertTrue(demo.isCallerOwner());

        // 换个调用者，就不是 owner 了
        address bob = address(0xB0B);
        vm.prank(bob);
        assertFalse(demo.isCallerOwner());
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 8】struct + 数组：添加多个用户能正确累计
    // ═════════════════════════════════════════════════════════════════════
    function test_AddMultipleUsers() public {
        demo.addUser("Alice");
        demo.addUser("Bob");
        demo.addUser("Carol");

        assertEq(demo.userCount(), 3);

        (string memory nick, uint256 score, bool active) = demo.users(1);
        assertEq(nick, "Bob");
        assertEq(score, 0);
        assertTrue(active);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【模糊测试】mapping 任意地址都返回 0（除非被存过）
    // ═════════════════════════════════════════════════════════════════════
    function testFuzz_MappingAlwaysDefaultZero(address anyAddr) public view {
        assertEq(demo.balanceOf(anyAddr), 0);
    }

    function testAddSore() public{
        address add = address(0xabc);
        uint256 score = 10;
        demo.addScore(add,score);
        assertEq(demo.scores(add), score);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎓 本测试文件验证了：
//   1. 构造函数初始化效果
//   2. mapping 的默认值特性
//   3. payable + msg.value 的工作方式
//   4. calldata 数组拷贝进 storage
//   5. memory 临时数组 + pure 函数
//   6. ⭐ storage 指针 vs memory 副本（L2 最重要的认知点）
//   7. 可见性 + private 工具函数 + external 暴露
//   8. struct 数组的添加与读取
//
// 跑命令：FOUNDRY_PROFILE=l2 forge test -vv
// ─────────────────────────────────────────────────────────────────────────────
