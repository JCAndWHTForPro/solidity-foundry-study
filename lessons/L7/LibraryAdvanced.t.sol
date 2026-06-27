// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./LibraryAdvanced.sol";

/// @title L7 测试合约：覆盖 Library、using for、struct、自定义类型、ABI 编解码、try/catch
contract LibraryAdvancedTest is Test {
    LibraryDemo public demo;
    Divider public divider;
    TryCatchDemo public tryCatchDemo;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        demo = new LibraryDemo();
        divider = new Divider();
        tryCatchDemo = new TryCatchDemo(address(divider));
    }

    // ═══════════════════════════════════════════════════════════════════
    // Library + using for 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_MathLibAdd() public view {
        (uint256 sum_,,,,) = demo.mathDemo(10, 5);
        assertEq(sum_, 15);
    }

    function test_MathLibSub() public view {
        (, uint256 diff,,,) = demo.mathDemo(10, 5);
        assertEq(diff, 5);
    }

    function test_MathLibPercentage() public view {
        (,, uint256 pct,,) = demo.mathDemo(200, 5);
        assertEq(pct, 20);  // 200 * 10% = 20
    }

    function test_MathLibMaxMin() public view {
        (,,, uint256 max_, uint256 min_) = demo.mathDemo(10, 5);
        assertEq(max_, 10);
        assertEq(min_, 5);
    }

    function test_MathLibSubUnderflow() public {
        // a < b 时应该 revert
        vm.expectRevert("MathLib: underflow");
        demo.mathDemo(3, 10);
    }

    // ═══════════════════════════════════════════════════════════════════
    // Struct + Profile 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_CreateProfile() public {
        vm.prank(alice);
        demo.createProfile("Alice", 25);

        (string memory name, uint256 age, uint256 score, bool active) = demo.getProfile(alice);
        assertEq(name, "Alice");
        assertEq(age, 25);
        assertEq(score, 0);
        assertTrue(active);
    }

    function test_CreateProfileEmptyNameReverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibraryDemo.InvalidName.selector, ""));
        demo.createProfile("", 25);
    }

    function test_GetProfileNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(LibraryDemo.ProfileNotFound.selector, alice));
        demo.getProfile(alice);
    }

    function test_AddScore() public {
        vm.prank(alice);
        demo.createProfile("Alice", 25);

        demo.addScore(alice, 50);

        (, , uint256 score, ) = demo.getProfile(alice);
        assertEq(score, 50);
    }

    function test_AddScoreMultiple() public {
        vm.prank(alice);
        demo.createProfile("Alice", 25);

        demo.addScore(alice, 30);
        demo.addScore(alice, 40);

        (, , uint256 score, ) = demo.getProfile(alice);
        assertEq(score, 70);
    }

    function test_AddScoreOutOfRange() public {
        vm.prank(alice);
        demo.createProfile("Alice", 25);

        vm.expectRevert(abi.encodeWithSelector(LibraryDemo.ScoreOutOfRange.selector, 101));
        demo.addScore(alice, 101);
    }

    // ═══════════════════════════════════════════════════════════════════
    // ArrayLib 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_ArrayContains() public {
        vm.prank(alice);
        demo.createProfile("Alice", 25);
        demo.addScore(alice, 42);

        assertTrue(demo.hasScore(42));
        assertFalse(demo.hasScore(99));
    }

    function test_ArraySum() public {
        vm.prank(alice);
        demo.createProfile("Alice", 25);
        demo.addScore(alice, 10);
        demo.addScore(alice, 20);
        demo.addScore(alice, 30);

        assertEq(demo.totalScore(), 60);
    }

    function test_ArrayRemoveUnordered() public {
        vm.prank(alice);
        demo.createProfile("Alice", 25);
        demo.addScore(alice, 10);
        demo.addScore(alice, 20);
        demo.addScore(alice, 30);

        // 删除 index=0（值为10），用最后一个元素（30）覆盖
        demo.removeScore(0);

        assertEq(demo.scoresLength(), 2);
        assertEq(demo.scores(0), 30); // 原来的30覆盖了位置0
        assertEq(demo.scores(1), 20);
    }

    // ═══════════════════════════════════════════════════════════════════
    // 自定义值类型 USD 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_PlaceOrder() public {
        vm.prank(alice);
        demo.placeOrder("Laptop", 99900); // $999.00

        (address buyer, , uint256 timestamp, string memory item) = demo.orders(0);
        assertEq(buyer, alice);
        assertEq(timestamp, block.timestamp);
        assertEq(item, "Laptop");
    }

    function test_TotalPrice() public {
        vm.prank(alice);
        demo.placeOrder("Laptop", 99900);    // $999.00

        vm.prank(bob);
        demo.placeOrder("Mouse", 4900);      // $49.00

        uint256 total = demo.totalPrice(0, 1);
        assertEq(total, 104800); // $1048.00
    }

    // ═══════════════════════════════════════════════════════════════════
    // ABI 编解码测试
    // ═══════════════════════════════════════════════════════════════════

    function test_ABIEncode() public view {
        bytes memory encoded = demo.encodeDemo(alice, 100);
        // abi.encode 输出 = 地址(32字节) + uint(32字节) = 64 字节
        assertEq(encoded.length, 64);
    }

    function test_ABIEncodePacked() public view {
        bytes memory packed = demo.encodePackedDemo(alice, 100);
        // abi.encodePacked = 地址(20字节) + uint256(32字节) = 52 字节
        assertEq(packed.length, 52);
    }

    function test_ABIDecode() public view {
        bytes memory data = abi.encode(alice, uint256(200));
        (address decodedAddr, uint256 decodedAmount) = demo.decodeDemo(data);
        assertEq(decodedAddr, alice);
        assertEq(decodedAmount, 200);
    }

    function test_ABIEncodeWithSignature() public view {
        bytes memory callData = demo.encodeCallDemo(alice, 1000);
        // 前4字节是 transfer(address,uint256) 的选择器
        bytes4 selector = bytes4(callData);
        assertEq(selector, bytes4(keccak256("transfer(address,uint256)")));
    }

    function test_HashDemo() public view {
        bytes32 hash1 = demo.hashDemo(alice, 1, "hello");
        bytes32 hash2 = demo.hashDemo(alice, 1, "hello");
        bytes32 hash3 = demo.hashDemo(alice, 2, "hello");

        // 相同输入 → 相同哈希
        assertEq(hash1, hash2);
        // 不同输入 → 不同哈希
        assertNotEq(hash1, hash3);
    }

    // ═══════════════════════════════════════════════════════════════════
    // 函数选择器测试
    // ═══════════════════════════════════════════════════════════════════

    function test_FunctionSelector() public view {
        bytes4 selector = demo.getCreateProfileSelector();
        bytes4 expected = bytes4(keccak256("createProfile(string,uint256)"));
        assertEq(selector, expected);
    }

    function test_ComputeSelector() public view {
        bytes4 computed = demo.computeSelector("transfer(address,uint256)");
        assertEq(computed, bytes4(0xa9059cbb));
    }

    function test_VerifySelector() public view {
        assertTrue(demo.verifySelector());
    }

    function test_ConstantSelector() public view {
        assertEq(demo.PROFILE_SELECTOR(), demo.getCreateProfileSelector());
    }

    // ═══════════════════════════════════════════════════════════════════
    // try/catch 测试
    // ═══════════════════════════════════════════════════════════════════

    function test_TryCatchSuccess() public {
        string memory result = tryCatchDemo.tryCatchRequire(10, 2);
        assertEq(result, "success");
    }

    function test_TryCatchRequireError() public {
        string memory result = tryCatchDemo.tryCatchRequire(10, 0);
        assertEq(result, "cannot divide by zero");
    }

    function test_TryCatchPanicSuccess() public {
        uint256 code = tryCatchDemo.tryCatchPanic(10, 2);
        assertEq(code, 0); // 0 表示成功
    }

    function test_TryCatchPanicDivByZero() public {
        uint256 code = tryCatchDemo.tryCatchPanic(10, 0);
        assertEq(code, 0x01); // Panic(0x01) = assert failure
    }

    function test_TryCatchCustomError() public {
        bytes memory data = tryCatchDemo.tryCatchCustom(10, 0);
        // 前4字节是 DivisionByZero() 的选择器
        bytes4 selector = bytes4(data);
        assertEq(selector, Divider.DivisionByZero.selector);
    }

    // ═══════════════════════════════════════════════════════════════════
    // Fuzz 测试
    // ═══════════════════════════════════════════════════════════════════

    function testFuzz_MathLibAddCommutative(uint128 a, uint128 b) public view {
        // mathDemo 内部会调用 sub(a,b)，所以需要 a >= b
        // 这里只测试加法交换律，确保 a >= b
        uint256 x = uint256(a);
        uint256 y = uint256(b);
        vm.assume(x >= y);
        (uint256 sum1,,,,) = demo.mathDemo(x, y);
        // 加法交换律验证：x + y == y + x
        assertEq(sum1, x + y);
        assertEq(sum1, y + x);
    }

    function testFuzz_ABIEncodeDecodeTripRound(address addr, uint256 amount) public view {
        bytes memory encoded = demo.encodeDemo(addr, amount);
        (address decoded_addr, uint256 decoded_amount) = demo.decodeDemo(encoded);
        assertEq(decoded_addr, addr);
        assertEq(decoded_amount, amount);
    }
}
