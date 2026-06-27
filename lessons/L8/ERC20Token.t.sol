// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./ERC20Token.sol";

/// @title L8 测试合约：覆盖 ERC20 全部核心功能
contract ERC20TokenTest is Test {
    MyERC20 public token;
    SimpleICO public ico;

    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 constant INITIAL_SUPPLY = 1_000_000 * 1e18;  // 100万代币
    uint256 constant CAP = 10_000_000 * 1e18;            // 1000万上限

    function setUp() public {
        vm.startPrank(deployer);
        token = new MyERC20("My Token", "MTK", 18, CAP, INITIAL_SUPPLY);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════
    // Metadata 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_Name() public view {
        assertEq(token.name(), "My Token");
    }

    function test_Symbol() public view {
        assertEq(token.symbol(), "MTK");
    }

    function test_Decimals() public view {
        assertEq(token.decimals(), 18);
    }

    // ═══════════════════════════════════════════════════════════════════
    // 初始状态测试
    // ═══════════════════════════════════════════════════════════════════

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_DeployerHasInitialBalance() public view {
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY);
    }

    function test_OtherAddressesHaveZeroBalance() public view {
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_Cap() public view {
        assertEq(token.cap(), CAP);
    }

    // ═══════════════════════════════════════════════════════════════════
    // transfer 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_Transfer() public {
        vm.prank(deployer);
        token.transfer(alice, 1000 * 1e18);

        assertEq(token.balanceOf(alice), 1000 * 1e18);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - 1000 * 1e18);
    }

    function test_TransferEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(deployer, alice, 500 * 1e18);

        vm.prank(deployer);
        token.transfer(alice, 500 * 1e18);
    }

    function test_TransferInsufficientBalance() public {
        vm.prank(alice); // alice 余额为 0
        vm.expectRevert(
            abi.encodeWithSelector(
                MyERC20.ERC20InsufficientBalance.selector,
                alice, 0, 100
            )
        );
        token.transfer(bob, 100);
    }

    function test_TransferToZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(MyERC20.ERC20InvalidReceiver.selector, address(0))
        );
        token.transfer(address(0), 100);
    }

    function test_TransferZeroAmount() public {
        vm.prank(deployer);
        bool success = token.transfer(alice, 0);
        assertTrue(success);
        assertEq(token.balanceOf(alice), 0);
    }

    // ═══════════════════════════════════════════════════════════════════
    // approve + allowance 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_Approve() public {
        vm.prank(alice);
        token.approve(bob, 500 * 1e18);

        assertEq(token.allowance(alice, bob), 500 * 1e18);
    }

    function test_ApproveEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IERC20.Approval(alice, bob, 300 * 1e18);

        vm.prank(alice);
        token.approve(bob, 300 * 1e18);
    }

    function test_ApproveOverrides() public {
        vm.startPrank(alice);
        token.approve(bob, 100);
        token.approve(bob, 200);
        vm.stopPrank();

        // 最终额度是 200（覆盖），不是 300
        assertEq(token.allowance(alice, bob), 200);
    }

    function test_ApproveToZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MyERC20.ERC20InvalidSpender.selector, address(0))
        );
        token.approve(address(0), 100);
    }

    function test_InfiniteApproval() public {
        vm.prank(alice);
        token.approve(bob, type(uint256).max);

        assertEq(token.allowance(alice, bob), type(uint256).max);
    }

    // ═══════════════════════════════════════════════════════════════════
    // transferFrom 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_TransferFrom() public {
        // deployer 给 alice 一些代币
        vm.prank(deployer);
        token.transfer(alice, 1000 * 1e18);

        // alice 授权 bob
        vm.prank(alice);
        token.approve(bob, 500 * 1e18);

        // bob 代扣 alice → charlie
        vm.prank(bob);
        token.transferFrom(alice, charlie, 200 * 1e18);

        assertEq(token.balanceOf(alice), 800 * 1e18);
        assertEq(token.balanceOf(charlie), 200 * 1e18);
        // 授权额度减少
        assertEq(token.allowance(alice, bob), 300 * 1e18);
    }

    function test_TransferFromInsufficientAllowance() public {
        vm.prank(deployer);
        token.transfer(alice, 1000 * 1e18);

        vm.prank(alice);
        token.approve(bob, 100 * 1e18);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                MyERC20.ERC20InsufficientAllowance.selector,
                bob, 100 * 1e18, 500 * 1e18
            )
        );
        token.transferFrom(alice, charlie, 500 * 1e18);
    }

    function test_TransferFromInfiniteApprovalNotDecreased() public {
        vm.prank(deployer);
        token.transfer(alice, 1000 * 1e18);

        // 无限授权
        vm.prank(alice);
        token.approve(bob, type(uint256).max);

        // bob 代扣
        vm.prank(bob);
        token.transferFrom(alice, charlie, 100 * 1e18);

        // 无限授权不会减少
        assertEq(token.allowance(alice, bob), type(uint256).max);
    }

    // ═══════════════════════════════════════════════════════════════════
    // mint 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_Mint() public {
        vm.prank(deployer);
        token.mint(alice, 500 * 1e18);

        assertEq(token.balanceOf(alice), 500 * 1e18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 500 * 1e18);
    }

    function test_MintOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MyERC20.OwnableUnauthorized.selector, alice)
        );
        token.mint(bob, 100);
    }

    function test_MintExceedsCap() public {
        uint256 remaining = CAP - INITIAL_SUPPLY;
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(
                MyERC20.ERC20ExceedsCap.selector,
                INITIAL_SUPPLY + remaining + 1,
                CAP
            )
        );
        token.mint(alice, remaining + 1);
    }

    function test_MintToZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(MyERC20.ERC20InvalidReceiver.selector, address(0))
        );
        token.mint(address(0), 100);
    }

    // ═══════════════════════════════════════════════════════════════════
    // burn 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_Burn() public {
        vm.prank(deployer);
        token.burn(100 * 1e18);

        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - 100 * 1e18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - 100 * 1e18);
    }

    function test_BurnInsufficientBalance() public {
        vm.prank(alice); // alice 余额为 0
        vm.expectRevert(
            abi.encodeWithSelector(
                MyERC20.ERC20InsufficientBalance.selector,
                alice, 0, 100
            )
        );
        token.burn(100);
    }

    function test_BurnFrom() public {
        vm.prank(deployer);
        token.transfer(alice, 1000 * 1e18);

        vm.prank(alice);
        token.approve(bob, 500 * 1e18);

        vm.prank(bob);
        token.burnFrom(alice, 200 * 1e18);

        assertEq(token.balanceOf(alice), 800 * 1e18);
        assertEq(token.allowance(alice, bob), 300 * 1e18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - 200 * 1e18);
    }

    // ═══════════════════════════════════════════════════════════════════
    // increaseAllowance / decreaseAllowance 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_IncreaseAllowance() public {
        vm.startPrank(alice);
        token.approve(bob, 100);
        token.increaseAllowance(bob, 50);
        vm.stopPrank();

        assertEq(token.allowance(alice, bob), 150);
    }

    function test_DecreaseAllowance() public {
        vm.startPrank(alice);
        token.approve(bob, 100);
        token.decreaseAllowance(bob, 40);
        vm.stopPrank();

        assertEq(token.allowance(alice, bob), 60);
    }

    function test_DecreaseAllowanceBelowZero() public {
        vm.startPrank(alice);
        token.approve(bob, 100);

        vm.expectRevert("ERC20: decreased below zero");
        token.decreaseAllowance(bob, 200);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════
    // SimpleICO 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_ICO_BuyTokens() public {
        // 设置 ICO：1 token = 0.001 ether
        uint256 tokenPrice = 0.001 ether; // 1e15 wei per token (1e18 最小单位)

        vm.startPrank(deployer);
        ico = new SimpleICO(address(token), tokenPrice);
        // deployer 转 10000 代币到 ICO 合约
        token.transfer(address(ico), 10000 * 1e18);
        vm.stopPrank();

        // alice 花 1 ether 买代币
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        ico.buyTokens{value: 1 ether}();

        // 1 ether / 0.001 ether per token = 1000 tokens
        assertEq(token.balanceOf(alice), 1000 * 1e18);
        assertEq(ico.totalRaised(), 1 ether);
    }

    function test_ICO_RemainingTokens() public {
        uint256 tokenPrice = 0.001 ether;

        vm.startPrank(deployer);
        ico = new SimpleICO(address(token), tokenPrice);
        token.transfer(address(ico), 5000 * 1e18);
        vm.stopPrank();

        assertEq(ico.remainingTokens(), 5000 * 1e18);
    }

    function test_ICO_NotActive() public {
        uint256 tokenPrice = 0.001 ether;

        vm.startPrank(deployer);
        ico = new SimpleICO(address(token), tokenPrice);
        token.transfer(address(ico), 5000 * 1e18);
        ico.setActive(false);
        vm.stopPrank();

        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SimpleICO.ICONotActive.selector));
        ico.buyTokens{value: 1 ether}();
    }

    function test_ICO_Withdraw() public {
        uint256 tokenPrice = 0.001 ether;

        vm.startPrank(deployer);
        ico = new SimpleICO(address(token), tokenPrice);
        token.transfer(address(ico), 10000 * 1e18);
        vm.stopPrank();

        // alice 购买
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        ico.buyTokens{value: 2 ether}();

        // deployer 提取 ETH
        uint256 balBefore = deployer.balance;
        vm.prank(deployer);
        ico.withdraw();
        assertEq(deployer.balance, balBefore + 2 ether);
    }

    // ═══════════════════════════════════════════════════════════════════
    // Fuzz 测试
    // ═══════════════════════════════════════════════════════════════════

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 0, INITIAL_SUPPLY);

        vm.prank(deployer);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - amount);
    }

    function testFuzz_ApproveAndTransferFrom(uint256 approveAmount, uint256 transferAmount) public {
        approveAmount = bound(approveAmount, 0, INITIAL_SUPPLY);
        transferAmount = bound(transferAmount, 0, approveAmount);

        vm.prank(deployer);
        token.transfer(alice, approveAmount);

        vm.prank(alice);
        token.approve(bob, approveAmount);

        vm.prank(bob);
        token.transferFrom(alice, charlie, transferAmount);

        assertEq(token.balanceOf(charlie), transferAmount);
        assertEq(token.balanceOf(alice), approveAmount - transferAmount);
    }
}
