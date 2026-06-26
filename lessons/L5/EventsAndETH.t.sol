// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./EventsAndETH.sol";

// ─────────────────────────────────────────────────────────────────────────────
// L5 测试：事件与 ETH 收发
//
// 本文件通过测试验证：
//   - 事件触发与参数
//   - payable 函数接收 ETH
//   - receive / fallback 行为
//   - 转账与余额更新
//   - 三种转账方式对比
//   - ETH 单位
// ─────────────────────────────────────────────────────────────────────────────

contract EventsAndETHTest is Test {
    EventsAndETH public vault;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        vault = new EventsAndETH();
        // 给测试地址一些 ETH
        vm.deal(alice, 10 ether);
        vm.deal(bob, 5 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 1】构造函数：owner 设置正确
    // ═════════════════════════════════════════════════════════════════════
    function test_ConstructorSetsOwner() public view {
        assertEq(vault.owner(), address(this));
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 2】deposit：存款成功 + 事件触发
    //
    //   vm.expectEmit(indexed1, indexed2, indexed3, checkData)
    //   用于验证下一次调用是否触发了预期的事件。
    // ═════════════════════════════════════════════════════════════════════
    function test_DepositSuccess() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit EventsAndETH.Deposited(alice, 1 ether, block.timestamp);

        vault.deposit{value: 1 ether}();

        assertEq(vault.balances(alice), 1 ether);
        assertEq(vault.totalDeposits(), 1 ether);
        assertEq(address(vault).balance, 1 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 3】deposit：金额太小会 revert
    // ═════════════════════════════════════════════════════════════════════
    function test_DepositTooSmallReverts() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                EventsAndETH.DepositTooSmall.selector,
                0.0001 ether,
                0.001 ether
            )
        );
        vault.deposit{value: 0.0001 ether}();
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 4】withdraw：取款成功
    // ═════════════════════════════════════════════════════════════════════
    function test_WithdrawSuccess() public {
        // 先存款
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        // 记录 alice 取款前余额
        uint256 aliceBalanceBefore = alice.balance;

        // 再取款
        vm.prank(alice);
        vault.withdraw(1 ether);

        assertEq(vault.balances(alice), 1 ether);
        assertEq(alice.balance, aliceBalanceBefore + 1 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 5】withdraw：余额不足 revert
    // ═════════════════════════════════════════════════════════════════════
    function test_WithdrawInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                EventsAndETH.InsufficientBalance.selector,
                1 ether,
                0
            )
        );
        vault.withdraw(1 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 6】receive()：纯 ETH 转账触发 receive
    //
    //   用 (bool, ) = addr.call{value: amount}("") 发送纯 ETH
    //   msg.data 为空 → 触发 receive()
    // ═════════════════════════════════════════════════════════════════════
    function test_ReceiveETH() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit EventsAndETH.Received(alice, 0.5 ether);

        (bool success, ) = address(vault).call{value: 0.5 ether}("");
        assertTrue(success);

        assertEq(vault.balances(alice), 0.5 ether);
        assertEq(address(vault).balance, 0.5 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 7】fallback()：带 calldata 的调用触发 fallback
    //
    //   调用一个合约上不存在的函数 → 触发 fallback
    // ═════════════════════════════════════════════════════════════════════
    function test_FallbackCalled() public {
        vm.prank(bob);
        vm.expectEmit(true, false, false, true);
        emit EventsAndETH.FallbackCalled(bob, 0.1 ether, hex"12345678");

        // 调用不存在的函数签名
        (bool success, ) = address(vault).call{value: 0.1 ether}(hex"12345678");
        assertTrue(success);

        assertEq(vault.balances(bob), 0.1 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 8】getContractBalance：查询合约余额
    // ═════════════════════════════════════════════════════════════════════
    function test_GetContractBalance() public {
        vm.prank(alice);
        vault.deposit{value: 3 ether}();

        assertEq(vault.getContractBalance(), 3 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 9】withdrawAll：owner 提取全部余额
    // ═════════════════════════════════════════════════════════════════════
    function test_WithdrawAllByOwner() public {
        // alice 存入
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        // bob 存入
        vm.prank(bob);
        vault.deposit{value: 1 ether}();

        // owner 提取全部
        uint256 ownerBefore = address(this).balance;
        vault.withdrawAll();

        assertEq(address(vault).balance, 0);
        assertEq(address(this).balance, ownerBefore + 3 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 10】withdrawAll：非 owner 不能调用
    // ═════════════════════════════════════════════════════════════════════
    function test_WithdrawAllNotOwner() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(EventsAndETH.NotOwner.selector, alice)
        );
        vault.withdrawAll();
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 11】ETH 单位验证
    // ═════════════════════════════════════════════════════════════════════
    function test_EthUnits() public view {
        (uint256 oneWei, uint256 oneGwei, uint256 oneEther) = vault.ethUnits();
        assertEq(oneWei, 1);
        assertEq(oneGwei, 1_000_000_000);
        assertEq(oneEther, 1_000_000_000_000_000_000);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 12】isVIP：存款达到 0.1 ether 门槛
    // ═════════════════════════════════════════════════════════════════════
    function test_IsVIP() public {
        assertFalse(vault.isVIP(alice));

        vm.prank(alice);
        vault.deposit{value: 0.1 ether}();

        assertTrue(vault.isVIP(alice));
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 13】sendViaCall：owner 用 call 转账
    // ═════════════════════════════════════════════════════════════════════
    function test_SendViaCall() public {
        // 先给合约充值
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        uint256 bobBefore = bob.balance;
        vault.sendViaCall(payable(bob), 0.5 ether);

        assertEq(bob.balance, bobBefore + 0.5 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 14】getBalance：零地址 revert
    // ═════════════════════════════════════════════════════════════════════
    function test_GetBalanceZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(EventsAndETH.ZeroAddress.selector));
        vault.getBalance(address(0));
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【模糊测试】任意金额存款（>= 最小值）都能正常工作
    // ═════════════════════════════════════════════════════════════════════
    function testFuzz_Deposit(uint256 amount) public {
        // 限制在合理范围：最小 0.001 ether，最大 100 ether
        amount = bound(amount, 0.001 ether, 100 ether);

        vm.deal(alice, amount);
        vm.prank(alice);
        vault.deposit{value: amount}();

        assertEq(vault.balances(alice), amount);
        assertEq(address(vault).balance, amount);
    }

    // 让测试合约能接收 ETH（withdrawAll 需要）
    receive() external payable {}
}


// ─────────────────────────────────────────────────────────────────────────────
// 🎓 本测试文件验证了：
//   1.  构造函数设置 owner
//   2.  deposit + 事件触发（vm.expectEmit）
//   3.  deposit 金额太小 revert
//   4.  withdraw 取款成功
//   5.  withdraw 余额不足 revert
//   6.  receive() 接收纯 ETH 转账
//   7.  fallback() 接收带 calldata 的调用
//   8.  getContractBalance 查询合约余额
//   9.  withdrawAll owner 提取
//   10. withdrawAll 非 owner 拒绝
//   11. ETH 单位正确性
//   12. isVIP 门槛判断
//   13. sendViaCall 转账
//   14. 零地址检查
//   15. 模糊测试存款
//
// 跑命令：FOUNDRY_PROFILE=l5 forge test -vv
// ─────────────────────────────────────────────────────────────────────────────
