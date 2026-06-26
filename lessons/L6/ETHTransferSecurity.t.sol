// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./ETHTransferSecurity.sol";

// ─────────────────────────────────────────────────────────────────────────────
// L6 测试：ETH 转账与安全
//
// 本文件验证：
//   - 漏洞合约被重入攻击成功
//   - 安全合约能抵御重入攻击
//   - CEI 模式 / 重入锁 / Pull 模式工作正常
//   - owner 权限控制
//   - 批量存款 + unchecked
// ─────────────────────────────────────────────────────────────────────────────

contract ETHTransferSecurityTest is Test {
    VulnerableBank public vulnerable;
    SecureBank public secure;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        vulnerable = new VulnerableBank();
        secure = new SecureBank();

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 1】VulnerableBank 正常存款
    // ═════════════════════════════════════════════════════════════════════
    function test_VulnerableDeposit() public {
        vm.prank(alice);
        vulnerable.deposit{value: 2 ether}();

        assertEq(vulnerable.balances(alice), 2 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 2】SecureBank 正常存款
    // ═════════════════════════════════════════════════════════════════════
    function test_SecureDeposit() public {
        vm.prank(alice);
        secure.deposit{value: 2 ether}();

        assertEq(secure.balances(alice), 2 ether);
        assertEq(secure.totalDeposits(), 2 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 3】SecureBank 取款成功
    // ═════════════════════════════════════════════════════════════════════
    function test_SecureWithdraw() public {
        vm.prank(alice);
        secure.deposit{value: 2 ether}();

        uint256 before = alice.balance;

        vm.prank(alice);
        secure.withdraw(1 ether);

        assertEq(secure.balances(alice), 1 ether);
        assertEq(secure.totalDeposits(), 1 ether);
        assertEq(alice.balance, before + 1 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 4】SecureBank 余额不足 revert
    // ═════════════════════════════════════════════════════════════════════
    function test_SecureWithdrawInsufficient() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureBank.InsufficientBalance.selector,
                1 ether,
                0
            )
        );
        secure.withdraw(1 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 5】重入攻击成功：VulnerableBank 被偷
    //
    //   攻击者存 1 ether，通过重入取走超过 1 ether。
    // ═════════════════════════════════════════════════════════════════════
    function test_ReentrancyAttackSucceedsOnVulnerable() public {
        // 给漏洞合约充 10 ether，模拟它是银行
        vm.deal(address(vulnerable), 10 ether);

        // 黑客合约部署
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(vulnerable));
        vm.deal(address(attacker), 1 ether);

        uint256 bankBefore = address(vulnerable).balance;
        uint256 attackerBefore = address(attacker).balance;

        attacker.attack{value: 1 ether}();

        uint256 stolen = address(attacker).balance - attackerBefore;

        // 黑客至少偷了 2 ether（自己的 1 ether + 额外 1+ ether）
        assertGt(stolen, 1 ether, "should steal more than deposited");
        assertLt(address(vulnerable).balance, bankBefore, "bank should lose ETH");
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 6】重入攻击失败：SecureBank 防御成功
    //
    //   黑客尝试同样的手法，但由于 CEI 先扣了余额，
    //   再次重入时余额不足，交易 revert。
    // ═════════════════════════════════════════════════════════════════════
    function test_ReentrancyAttackFailsOnSecure() public {
        vm.deal(address(secure), 10 ether);

        FailedAttacker attacker = new FailedAttacker(payable(address(secure)));
        vm.deal(address(attacker), 1 ether);

        uint256 bankBefore = address(secure).balance;
        uint256 attackerBefore = address(attacker).balance;

        // 攻击交易会因为重入时余额不足而整体 revert
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureBank.TransferFailed.selector,
                address(attacker),
                0.5 ether
            )
        );
        attacker.attack{value: 1 ether}();

        // 银行的余额应该没有变化
        assertEq(address(secure).balance, bankBefore);

        // 黑客连本金都没损失（因为攻击交易整体 revert）
        assertEq(address(attacker).balance, attackerBefore);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 6.5】专门验证 nonReentrant 重入锁会触发 ReentrantCall
    //
    //   在 SecureBank 里新增一个被 nonReentrant 保护的函数，
    //   黑客在 receive 里调用它，会直接触发 ReentrantCall。
    // ═════════════════════════════════════════════════════════════════════
    function test_NonReentrantLockTriggersReentrantCall() public {
        vm.deal(address(secure), 10 ether);

        LockTester tester = new LockTester(payable(address(secure)));
        vm.deal(address(tester), 1 ether);

        vm.expectRevert(SecureBank.ReentrantCall.selector);
        tester.attack{value: 1 ether}();
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 7】非 owner 不能调用 ownerWithdraw
    // ═════════════════════════════════════════════════════════════════════
    function test_OwnerWithdrawOnlyOwner() public {
        vm.deal(address(secure), 1 ether);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SecureBank.NotOwner.selector, alice));
        secure.ownerWithdraw();
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 8】ownerWithdraw 成功
    // ═════════════════════════════════════════════════════════════════════
    function test_OwnerWithdrawSuccess() public {
        // 先让 alice 存点钱
        vm.prank(alice);
        secure.deposit{value: 2 ether}();

        // 再直接给合约打 0.5 ether（模拟手续费收入）
        vm.deal(address(secure), address(secure).balance + 0.5 ether);

        uint256 ownerBefore = address(this).balance;
        uint256 contractBalance = address(secure).balance;

        secure.ownerWithdraw();

        assertEq(address(this).balance, ownerBefore + contractBalance);
        assertEq(address(secure).balance, 0);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 9】withdrawAll 一次性取完
    // ═════════════════════════════════════════════════════════════════════
    function test_WithdrawAll() public {
        vm.prank(alice);
        secure.deposit{value: 3 ether}();

        uint256 before = alice.balance;

        vm.prank(alice);
        secure.withdrawAll();

        assertEq(secure.balances(alice), 0);
        assertEq(secure.totalDeposits(), 0);
        assertEq(alice.balance, before + 3 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 10】batchDepositFor：批量加余额
    // ═════════════════════════════════════════════════════════════════════
    function test_BatchDepositFor() public {
        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        secure.batchDepositFor{value: 3 ether}(users, amounts);

        assertEq(secure.balances(alice), 1 ether);
        assertEq(secure.balances(bob), 2 ether);
        assertEq(secure.totalDeposits(), 3 ether);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 11】batchDepositFor：金额不匹配 revert
    // ═════════════════════════════════════════════════════════════════════
    function test_BatchDepositForAmountMismatch() public {
        address[] memory users = new address[](1);
        users[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2 ether;

        vm.expectRevert(SecureBank.ZeroAmount.selector);
        secure.batchDepositFor{value: 1 ether}(users, amounts);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 12】deposit 0 ether revert
    // ═════════════════════════════════════════════════════════════════════
    function test_DepositZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(SecureBank.ZeroAmount.selector);
        secure.deposit{value: 0}();
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【测试 13】ownerWithdraw 余额为 0 revert
    // ═════════════════════════════════════════════════════════════════════
    function test_OwnerWithdrawZeroReverts() public {
        vm.expectRevert(SecureBank.ZeroAmount.selector);
        secure.ownerWithdraw();
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【模糊测试】任意金额的存取都能保持会计恒等式
    // ═════════════════════════════════════════════════════════════════════
    function testFuzz_DepositWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        depositAmount = bound(depositAmount, 1 wei, 100 ether);
        withdrawAmount = bound(withdrawAmount, 0, depositAmount);

        vm.deal(alice, depositAmount);

        vm.prank(alice);
        secure.deposit{value: depositAmount}();

        vm.prank(alice);
        secure.withdraw(withdrawAmount);

        assertEq(secure.balances(alice), depositAmount - withdrawAmount);
        assertEq(secure.totalDeposits(), depositAmount - withdrawAmount);
    }

    // 让测试合约能接收 ETH
    receive() external payable {}
}
