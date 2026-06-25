// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// L4 · 继承、接口、抽象合约
//
// 💡 本文件演示 Solidity 面向对象体系的核心：
//    继承 (is)、多重继承、函数重写 (virtual/override)、super、
//    抽象合约 (abstract)、接口 (interface)、构造函数参数传递。
//
// Java 程序员注意：
//   - Solidity 支持多重继承（Java 只有单继承 + 接口）
//   - 继承线性化用 C3 算法（Python 的 MRO 同款）
//   - interface 和 Java 的接口很像，但限制更严格
// ─────────────────────────────────────────────────────────────────────────────


// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 1】接口（Interface）
//
//   • 关键字：interface
//   • 规则：
//     1) 不能有状态变量
//     2) 不能有构造函数
//     3) 所有函数必须是 external（不写函数体）
//     4) 不能继承普通合约，只能继承其他接口
//     5) 不能有 modifier
//
//   • 用途：
//     - 定义标准（如 ERC20、ERC721）
//     - 类型约束：指定"对方必须有这些函数"
//     - 跨合约调用的类型安全保障
//
//   💡 类比 Java：几乎等同于 Java 8 之前的 interface（没有 default 方法）
// ═════════════════════════════════════════════════════════════════════════════

interface IAnimal {
    /// 返回动物的叫声
    function speak() external view returns (string memory);

    /// 返回动物的腿数
    function legs() external pure returns (uint256);

    /// 喂食事件
    event Fed(address indexed feeder, string food);
}


// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 2】抽象合约（Abstract Contract）
//
//   • 关键字：abstract contract
//   • 特点：
//     1) 可以有状态变量（接口不行）
//     2) 可以有构造函数
//     3) 可以有已实现的函数和未实现的函数
//     4) 未实现的函数必须标注 virtual
//     5) 不能直接部署（必须被继承后实现所有函数）
//
//   💡 类比 Java：等同于 abstract class
//   💡 和接口的区别：抽象合约可以有状态、可以有函数体，接口全是空壳。
// ═════════════════════════════════════════════════════════════════════════════

abstract contract Animal is IAnimal {
    // 状态变量（接口里不能有，但抽象合约可以）
    string public name;
    address public owner;

    // 构造函数（接口里不能有，但抽象合约可以）
    constructor(string memory _name) {
        name = _name;
        owner = msg.sender;
    }

    /// 已实现的函数：喂食（子合约可以直接用）
    function feed(string memory food) external {
        emit Fed(msg.sender, food);
    }

    /// 未实现的函数：speak() 留给子合约实现
    /// 注意：必须标注 virtual，告诉编译器"这个函数可以/需要被重写"
    function speak() external view virtual returns (string memory);

    /// 已实现 + virtual：子合约可以重写，也可以不重写
    function description() external view virtual returns (string memory) {
        return string(abi.encodePacked("I am ", name));
    }
}


// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 3】继承（Inheritance）+ 函数重写
//
//   • 语法：contract Child is Parent { ... }
//   • 重写规则：
//     1) 父合约函数必须标注 virtual → 才能被重写
//     2) 子合约重写必须标注 override
//     3) 如果子合约还想让孙合约继续重写 → virtual override
//
//   • 状态变量继承：子合约自动拥有父合约的所有状态变量
//   • 函数继承：子合约自动拥有父合约所有 public/internal 函数
//
//   💡 类比 Java：is = extends，virtual = 非 final，override = @Override
// ═════════════════════════════════════════════════════════════════════════════

contract Dog is Animal {
    string private _sound;

    // 【知识点 4】构造函数参数传递
    //
    //   子合约必须调用父合约的构造函数。两种写法：
    //
    //   写法 1（推荐）：直接在继承列表里传参
    //     contract Dog is Animal("Buddy") { ... }
    //
    //   写法 2：在子合约构造函数里传参
    //     constructor(string memory _name) Animal(_name) { ... }
    //
    //   💡 类比 Java：等同于 super(_name) 调用父构造函数
    constructor(string memory _name, string memory sound_) Animal(_name) {
        _sound = sound_;
    }

    /// 实现接口的 speak()：必须写 override
    function speak() external view override returns (string memory) {
        return _sound;
    }

    /// 实现接口的 legs()：狗有 4 条腿
    function legs() external pure override returns (uint256) {
        return 4;
    }

    /// 重写 description()：增强父合约的行为
    /// 注意：这里可以用 virtual override，允许进一步被重写
    function description() external view virtual override returns (string memory) {
        return string(abi.encodePacked(name, " says ", _sound));
    }
}


// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 5】多重继承 + C3 线性化
//
//   • Solidity 支持多重继承：contract C is A, B { ... }
//   • 继承顺序很重要！从"最基础"到"最派生"从左往右写
//   • 编译器用 C3 线性化算法 决定函数的调用顺序
//
//   重要规则：
//     - 继承列表从左到右 = 从最基础到最派生
//     - 如果多个父合约有同名函数，子合约必须 override 所有
//     - override(A, B) 语法指明重写了哪些父合约的函数
//
//   💡 Java 对比：Java 不支持多重继承类，只能多实现接口；
//     Solidity 允许多继承合约，但需要程序员处理冲突。
// ═════════════════════════════════════════════════════════════════════════════

/// 定义一个"可暂停"能力（Mixin 模式）
abstract contract Pausable {
    bool public paused;
    address internal _pauseAdmin;

    error ContractPaused();
    error NotPauseAdmin(address caller);

    event Paused(address account);
    event Unpaused(address account);

    constructor() {
        _pauseAdmin = msg.sender;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    function pause() external {
        if (msg.sender != _pauseAdmin) revert NotPauseAdmin(msg.sender);
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external {
        if (msg.sender != _pauseAdmin) revert NotPauseAdmin(msg.sender);
        paused = false;
        emit Unpaused(msg.sender);
    }
}

/// 定义一个"可计数"能力
abstract contract Countable {
    uint256 public count;

    event Counted(uint256 newCount);

    function _increment() internal {
        count += 1;
        emit Counted(count);
    }
}


// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 6】多重继承实战 + super 关键字
//
//   • super 调用"继承链上的下一个合约"的同名函数
//   • 注意：super 不是固定调用"直接父合约"，而是按 C3 线性化顺序
//   • 所有继承链上的合约的同名函数都会被调用（如果每层都 super）
//
//   💡 类比 Java：super.method() 调用直接父类；
//     Solidity 的 super 按线性化链走，更像 Python 的 super()。
// ═════════════════════════════════════════════════════════════════════════════

// PetShop 放在下面用 DogV2 + internal 函数正确实现（见【知识点 7 补充】）


// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 7 补充】用 internal 函数配合继承复用逻辑
//
//   external 函数不能在合约内部通过 this 以外的方式直接调用。
//   常见模式：把核心逻辑放在 internal 函数里，external 函数只是薄包装。
//
//   这也是 OpenZeppelin 库的标准模式：
//     function transfer(address to, uint256 amount) external { _transfer(...); }
//     function _transfer(...) internal { ... }
// ═════════════════════════════════════════════════════════════════════════════


// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 8】接口类型做参数 —— 多态
//
//   • 可以把接口类型作为函数参数，实现"面向接口编程"
//   • 调用者只要传入"实现了该接口的任何合约"都行
//   • 这是 DeFi 协议组合性的基础（如 Uniswap 接受任何 IERC20 代币）
//
//   💡 类比 Java：方法参数声明为接口类型 → 传入任何实现类的实例
// ═════════════════════════════════════════════════════════════════════════════

contract AnimalChecker {
    /// 传入任何实现了 IAnimal 的合约，返回其信息
    function getInfo(IAnimal animal) external view returns (string memory sound, uint256 legCount) {
        sound = animal.speak();
        legCount = animal.legs();
    }

    /// 检查一个动物是否是四足动物
    function isFourLegged(IAnimal animal) external pure returns (bool) {
        return animal.legs() == 4;
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 为了让 PetShop 能调用 Dog 的 description 逻辑，
// 我们重新定义一个带 internal helper 的版本：
// ─────────────────────────────────────────────────────────────────────────────

contract DogV2 is Animal {
    string private _sound;

    constructor(string memory _name, string memory sound_) Animal(_name) {
        _sound = sound_;
    }

    function speak() external view override returns (string memory) {
        return _sound;
    }

    function legs() external pure override returns (uint256) {
        return 4;
    }

    /// external 包装：对外暴露（加 virtual 允许子合约重写）
    function description() external view virtual override returns (string memory) {
        return _description();
    }

    /// internal 核心逻辑：子合约可以复用
    function _description() internal view returns (string memory) {
        return string(abi.encodePacked(name, " says ", _sound));
    }
}

/// PetShopV2：正确的多继承 + internal 复用模式
contract PetShopV2 is DogV2, Pausable, Countable {
    constructor(string memory _name, string memory _sound)
        DogV2(_name, _sound)
    {}

    function register() external whenNotPaused {
        _increment();
    }

    /// 重写 description：复用父合约的 internal 函数
    function description() external view override(DogV2) returns (string memory) {
        return string(abi.encodePacked("[PetShop] ", _description()));
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 🎓 本文件涵盖的 8 个知识点：
//   1. 接口（interface）—— 定义标准、类型约束
//   2. 抽象合约（abstract）—— 部分实现 + 强制子合约完成
//   3. 继承（is）+ 函数重写（virtual/override）
//   4. 构造函数参数传递（子调父）
//   5. 多重继承 + C3 线性化
//   6. super 关键字 + 继承链调用
//   7. internal 函数复用模式（OpenZeppelin 标准）
//   8. 接口类型做参数 —— 面向接口编程 / 多态
//
// 下一步：去看 Inheritance.t.sol，从测试里验证这些知识点。
// ─────────────────────────────────────────────────────────────────────────────
