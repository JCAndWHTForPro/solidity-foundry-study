// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./Inheritance.sol";

// ─────────────────────────────────────────────────────────────────────────────
// L4 测试：继承、接口、抽象合约
//
// 本文件通过测试验证继承体系中的核心行为：
//   - 构造函数参数传递
//   - 函数重写（virtual/override）
//   - 接口实现
//   - 多重继承能力组合
//   - 接口类型多态
//   - internal 函数复用模式
// ─────────────────────────────────────────────────────────────────────────────

contract InheritanceTest is Test {
    Dog public dog;
    DogV2 public dogV2;
    PetShopV2 public petShop;
    AnimalChecker public checker;

    address alice = address(0xA11CE);

    function setUp() public {
        dog = new Dog("Buddy", "Woof!");
        dogV2 = new DogV2("Rex", "Bark!");
        petShop = new PetShopV2("Luna", "Arf!");
        checker = new AnimalChecker();
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 1】构造函数参数传递：子 → 父
    //
    //   Dog 的构造函数把 _name 传给 Animal，Animal 保存到 state
    // ═════════════════════════════════════════════════════════════════════
    function test_ConstructorPassesParams() public view {
        assertEq(dog.name(), "Buddy");
        assertEq(dog.owner(), address(this)); // 部署者是测试合约自己
    }

    function test_DogV2ConstructorPassesParams() public view {
        assertEq(dogV2.name(), "Rex");
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 2】接口实现：speak() 和 legs()
    //
    //   Dog 实现了 IAnimal 接口的两个函数
    // ═════════════════════════════════════════════════════════════════════
    function test_DogImplementsIAnimal() public view {
        assertEq(dog.speak(), "Woof!");
        assertEq(dog.legs(), 4);
    }

    function test_DogV2ImplementsIAnimal() public view {
        assertEq(dogV2.speak(), "Bark!");
        assertEq(dogV2.legs(), 4);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 3】函数重写：description() 在子合约中被增强
    // ═════════════════════════════════════════════════════════════════════
    function test_DogOverridesDescription() public view {
        // Dog 重写了 Animal 的 description()
        assertEq(dog.description(), "Buddy says Woof!");
    }

    function test_DogV2Description() public view {
        assertEq(dogV2.description(), "Rex says Bark!");
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 4】抽象合约的已实现函数：feed() 直接继承可用
    //
    //   Animal 里的 feed() 已经实现了，子合约直接继承
    // ═════════════════════════════════════════════════════════════════════
    function test_InheritedFeedFunction() public {
        // 验证 feed 不会 revert，且触发事件
        vm.expectEmit(true, false, false, true);
        emit IAnimal.Fed(address(this), "bone");
        dog.feed("bone");
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 5】多重继承：PetShopV2 同时拥有 DogV2 + Pausable + Countable
    // ═════════════════════════════════════════════════════════════════════
    function test_PetShopMultipleInheritance() public {
        // 继承了 DogV2 的能力
        assertEq(petShop.speak(), "Arf!");
        assertEq(petShop.legs(), 4);
        assertEq(petShop.name(), "Luna");

        // 继承了 Countable 的能力
        assertEq(petShop.count(), 0);
        petShop.register();
        assertEq(petShop.count(), 1);

        // 继承了 Pausable 的能力
        assertFalse(petShop.paused());
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 6】Pausable modifier：暂停后 register 被拦截
    // ═════════════════════════════════════════════════════════════════════
    function test_PetShopPausable() public {
        petShop.pause();
        assertTrue(petShop.paused());

        vm.expectRevert(abi.encodeWithSelector(Pausable.ContractPaused.selector));
        petShop.register();
    }

    function test_PetShopPauseOnlyAdmin() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Pausable.NotPauseAdmin.selector, alice));
        petShop.pause();
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 7】internal 函数复用：PetShopV2 的 description 调用父合约 _description()
    // ═════════════════════════════════════════════════════════════════════
    function test_PetShopDescriptionUsesInternal() public view {
        // PetShopV2.description() 在前面加了 [PetShop] 前缀
        assertEq(petShop.description(), "[PetShop] Luna says Arf!");
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 8】接口类型做参数 —— 多态
    //
    //   AnimalChecker.getInfo() 接受任何 IAnimal 实现
    // ═════════════════════════════════════════════════════════════════════
    function test_InterfacePolymorphism() public view {
        // 传入 Dog 实例
        (string memory sound, uint256 legCount) = checker.getInfo(IAnimal(address(dog)));
        assertEq(sound, "Woof!");
        assertEq(legCount, 4);

        // 传入 PetShopV2 实例（也实现了 IAnimal）
        (string memory sound2, uint256 legCount2) = checker.getInfo(IAnimal(address(petShop)));
        assertEq(sound2, "Arf!");
        assertEq(legCount2, 4);
    }

    function test_CheckerIsFourLegged() public view {
        assertTrue(checker.isFourLegged(IAnimal(address(dog))));
        assertTrue(checker.isFourLegged(IAnimal(address(petShop))));
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 9】继承的状态变量：owner 由 Animal 构造函数设置
    // ═════════════════════════════════════════════════════════════════════
    function test_InheritedStateVariables() public view {
        // Dog/DogV2/PetShopV2 都继承了 Animal 的 owner
        assertEq(dog.owner(), address(this));
        assertEq(dogV2.owner(), address(this));
        assertEq(petShop.owner(), address(this));
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【测试 10】多重继承 Countable：连续注册递增
    // ═════════════════════════════════════════════════════════════════════
    function test_CountableIncrement() public {
        petShop.register();
        petShop.register();
        petShop.register();
        assertEq(petShop.count(), 3);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【模糊测试】任何 string 作为 name 都能正常构造
    // ═════════════════════════════════════════════════════════════════════
    function testFuzz_DogConstructor(string memory _name) public {
        Dog fuzzDog = new Dog(_name, "Woof!");
        assertEq(fuzzDog.name(), _name);
        assertEq(fuzzDog.speak(), "Woof!");
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 🎓 本测试文件验证了：
//   1.  构造函数参数从子合约传递到父合约
//   2.  接口实现（speak / legs）
//   3.  函数重写（description override）
//   4.  抽象合约已实现函数的继承（feed）
//   5.  多重继承能力组合（DogV2 + Pausable + Countable）
//   6.  Pausable modifier 的拦截能力
//   7.  internal 函数复用模式
//   8.  接口类型多态（传入不同实现给同一个函数）
//   9.  继承的状态变量（owner）
//   10. 多次调用验证 Countable 的递增逻辑
//   11. 模糊测试构造函数健壮性
//
// 跑命令：FOUNDRY_PROFILE=l4 forge test -vv
// ─────────────────────────────────────────────────────────────────────────────
