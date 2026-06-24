// SPDX-License-Identifier: MIT
// ─────────────────────────────────────────────────────────────────────────────
// 【L3 · 测试文件】ControlFlow.t.sol —— 用测试验证控制流与错误处理
//
// 📚 讲义全部写在注释里。这一节最关键的目标是：让学员用「测试」的方式，
//    亲眼看见 modifier 怎么拦截、revert 怎么捕获、循环怎么工作。
// ─────────────────────────────────────────────────────────────────────────────

pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ControlFlow} from "./ControlFlow.sol";


contract ControlFlowTest is Test {
    ControlFlow internal cf;
    address internal alice;
    address internal bob;

    function setUp() public {
        cf = new ControlFlow();
        alice = address(0xA11CE);
        bob = address(0xB0B);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 1】构造函数：owner 是部署者，初始状态正确
    // ═════════════════════════════════════════════════════════════════════
    function test_ConstructorSetsOwner() public view {
        assertEq(cf.owner(), address(this));
        assertEq(cf.paused(), false);
        assertEq(cf.counter(), 0);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 2】if/else：getGrade 正确返回等级
    // ═════════════════════════════════════════════════════════════════════
    function test_GetGrade() public view {
        assertEq(cf.getGrade(95), "A");
        assertEq(cf.getGrade(90), "A");
        assertEq(cf.getGrade(85), "B");
        assertEq(cf.getGrade(80), "B");
        assertEq(cf.getGrade(70), "C");
        assertEq(cf.getGrade(60), "C");
        assertEq(cf.getGrade(59), "D");
        assertEq(cf.getGrade(0), "D");
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 3】三元运算符：max 函数
    // ═════════════════════════════════════════════════════════════════════
    function test_Max() public view {
        assertEq(cf.max(10, 20), 20);
        assertEq(cf.max(99, 1), 99);
        assertEq(cf.max(5, 5), 5);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 4】require 错误：分数超过 100 会 revert
    //
    //   vm.expectRevert("字符串") 表示下一次调用必须 revert 且错误信息匹配。
    //   如果没有 revert，测试就会失败。
    // ═════════════════════════════════════════════════════════════════════
    function test_AddScoreRequireRevert() public {
        vm.expectRevert("score must be <= 100");
        cf.addScore(101);
    }

    function test_AddScoreSuccess() public {
        cf.addScore(85);
        assertEq(cf.scores(0), 85);
        assertEq(cf.scoresLength(), 1);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 5】自定义错误：addScoreStrict 的精细校验
    //
    //   捕获 custom error 需要用 abi.encodeWithSelector 或
    //   abi.encodeWithSignature 来匹配。
    // ═════════════════════════════════════════════════════════════════════
    function test_AddScoreStrictZeroReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ControlFlow.InvalidScore.selector,
                uint256(0),
                "score cannot be zero"
            )
        );
        cf.addScoreStrict(0);
    }

    function test_AddScoreStrictOver100Reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ControlFlow.InvalidScore.selector,
                uint256(200),
                "score exceeds maximum"
            )
        );
        cf.addScoreStrict(200);
    }

    function test_AddScoreStrictSuccess() public {
        cf.addScoreStrict(75);
        assertEq(cf.scores(0), 75);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 6】modifier onlyOwner：非 owner 调用会被拦截
    //
    //   vm.prank(addr) 模拟下一次调用的 msg.sender 为 addr。
    // ═════════════════════════════════════════════════════════════════════
    function test_OnlyOwnerBlocksNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ControlFlow.NotOwner.selector,
                alice,
                address(this)   // owner 是测试合约
            )
        );
        cf.pause();
    }

    function test_OnlyOwnerAllowsOwner() public {
        cf.pause();
        assertTrue(cf.paused());

        cf.unpause();
        assertFalse(cf.paused());
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 7】modifier whenNotPaused：暂停后操作被拒绝
    // ═════════════════════════════════════════════════════════════════════
    function test_WhenPausedBlocksActions() public {
        cf.pause();

        vm.expectRevert(
            abi.encodeWithSelector(ControlFlow.ContractPaused.selector)
        );
        cf.addScore(50);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 8】modifier 叠加：白名单 + 未暂停
    // ═════════════════════════════════════════════════════════════════════
    function test_VipIncrementRequiresWhitelist() public {
        // alice 不在白名单，调用 vipIncrement 应该 revert
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ControlFlow.NotWhitelisted.selector, alice)
        );
        cf.vipIncrement();
    }

    function test_VipIncrementWorksForWhitelisted() public {
        cf.addToWhitelist(alice);

        vm.prank(alice);
        cf.vipIncrement();

        assertEq(cf.counter(), 10);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 9】for 循环：totalScore 累加
    // ═════════════════════════════════════════════════════════════════════
    function test_TotalScore() public {
        cf.addScore(10);
        cf.addScore(20);
        cf.addScore(30);

        assertEq(cf.totalScore(), 60);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 10】while + revert：findFirstAbove
    // ═════════════════════════════════════════════════════════════════════
    function test_FindFirstAbove() public {
        cf.addScore(10);
        cf.addScore(50);
        cf.addScore(80);

        assertEq(cf.findFirstAbove(40), 50);
        assertEq(cf.findFirstAbove(70), 80);
    }

    function test_FindFirstAboveRevertsWhenNoneFound() public {
        cf.addScore(10);
        cf.addScore(20);

        vm.expectRevert(
            abi.encodeWithSelector(ControlFlow.NoScores.selector)
        );
        cf.findFirstAbove(100);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 11】increment + assert：正常递增
    // ═════════════════════════════════════════════════════════════════════
    function test_Increment() public {
        cf.increment();
        assertEq(cf.counter(), 1);

        cf.increment();
        assertEq(cf.counter(), 2);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【模糊测试】getGrade 对任意 score 都不会 revert
    // ═════════════════════════════════════════════════════════════════════
    function testFuzz_GetGradeNeverReverts(uint256 score) public view {
        // 无论传什么值，pure 函数都应该正常返回，不 revert
        string memory grade = cf.getGrade(score);
        // grade 一定是 A/B/C/D 之一
        assertTrue(
            keccak256(bytes(grade)) == keccak256("A") ||
            keccak256(bytes(grade)) == keccak256("B") ||
            keccak256(bytes(grade)) == keccak256("C") ||
            keccak256(bytes(grade)) == keccak256("D")
        );
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎓 本测试文件验证了：
//   1.  构造函数初始化 owner/paused/counter
//   2.  if/else 分支逻辑（getGrade）
//   3.  三元运算符（max）
//   4.  require("msg") 的 revert 捕获
//   5.  custom error 的 revert 捕获（abi.encodeWithSelector）
//   6.  onlyOwner modifier 的权限拦截
//   7.  whenNotPaused modifier 的状态拦截
//   8.  modifier 叠加（白名单 + 未暂停）
//   9.  for 循环累加
//   10. while 循环查找 + revert
//   11. increment + assert 内部不变量
//   12. 模糊测试确保 pure 函数对任意输入都安全
//
// 跑命令：FOUNDRY_PROFILE=l3 forge test -vv
// ─────────────────────────────────────────────────────────────────────────────
