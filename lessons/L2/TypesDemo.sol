// SPDX-License-Identifier: MIT
// ─────────────────────────────────────────────────────────────────────────────
// 【L2 · 主合约】TypesDemo.sol —— 数据类型、可见性、数据位置一站式演示
//
// 📚 本文件就是讲义本身。每个"知识点"都用注释包起来，逐段念给学员听。
// ─────────────────────────────────────────────────────────────────────────────

pragma solidity ^0.8.13;


/// @title TypesDemo - 演示 Solidity 类型系统
/// @notice 一份"看完就能掌握类型 + 可见性 + 数据位置"的合约
contract TypesDemo {

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 1】值类型 vs 引用类型
    //
    //   ▶ 值类型：bool / int / uint / address / bytesN / enum
    //     特点：赋值即「复制」，互不影响。
    //
    //   ▶ 引用类型：string / bytes / 数组 / mapping / struct
    //     特点：赋值即「引用」，可能共享底层数据，必须告诉编译器「住在哪」。
    //
    //   ▶ Solidity 没有 null / undefined，所有变量都有"默认值"：
    //       bool      → false
    //       uint/int  → 0
    //       address   → address(0)
    //       string    → ""
    //       bytes     → ""
    //       数组      → 空数组（长度 0）
    //       mapping   → 所有 key 都映射到默认值
    //       struct    → 每个字段都取自己类型的默认值
    // ═════════════════════════════════════════════════════════════════════


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 2】可见性（visibility）
    //
    //   • public   —— 外部 + 内部都能调用；自动生成同名 getter
    //   • external —— 只能从合约外部调用（this.foo() 也算外部）
    //   • internal —— 本合约 + 继承的子合约可调用（默认值）
    //   • private  —— 只能在「定义它的那个合约」里调用
    //
    //   ⚠️ private 不是"链上看不见"！它只是 Solidity 编译器层面的访问控制，
    //       任何人都能通过 RPC 读链上的 storage。
    // ═════════════════════════════════════════════════════════════════════

    // public 状态变量 → 编译器自动生成同名 getter
    bool   public flag;          // 默认 false
    uint8  public smallNumber;   // 默认 0；范围 0 ~ 255
    int256 public signedNumber;  // 默认 0；可正可负
    address public owner;        // 默认 address(0)
    bytes32 public dataHash;     // 定长字节，常用作哈希值

    // private 状态变量 → 不会生成 getter，但链上数据仍可被外部读取
    uint256 private secret;


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 3】枚举 enum —— 本质就是从 0 开始的 uint8
    // ═════════════════════════════════════════════════════════════════════
    enum Status { Pending, Active, Closed }   // 0, 1, 2
    Status public status;                     // 默认 Status.Pending (= 0)


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 4】引用类型：数组、字符串、struct、mapping
    // ═════════════════════════════════════════════════════════════════════

    uint256[] public numbers;                 // 动态数组
    uint256[3] public fixedNumbers;           // 定长数组，长度恒为 3

    string public name;                       // 动态长度字符串（UTF-8 字节）

    struct User {
        string nickname;
        uint256 score;
        bool active;
    }
    // struct 数组：多个 User 排在一起，可遍历
    User[] public users;

    // mapping：key-value 映射
    //   • mapping 没有 length，不可遍历；
    //   • 没插入过的 key，读出来是 value 类型的默认值；
    //   • mapping 必须放在 storage（不能作为函数局部变量声明为 memory）。
    mapping(address => uint256) public balanceOf;


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 5】构造函数：用来初始化状态变量
    // ═════════════════════════════════════════════════════════════════════
    constructor() {
        owner       = msg.sender;
        flag        = true;
        smallNumber = 42;
        signedNumber = -100;
        name        = "Solidity";
        dataHash    = keccak256(abi.encodePacked("hello"));
        status      = Status.Active;
        secret      = 12345;
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 6】数据位置：storage / memory / calldata
    //
    //   ▶ storage  —— 永久存在链上，写一次很贵（~20000 gas / slot）
    //   ▶ memory   —— 函数执行期间的临时内存，函数返回后销毁
    //   ▶ calldata —— 外部调用的"原始入参区"，只读 + 最便宜
    //
    //   ✅ 规则：
    //     1) 状态变量永远在 storage（不用写）
    //     2) 函数里的引用类型局部变量必须显式 memory 或 storage
    //     3) external 函数的引用类型参数推荐 calldata（省 gas）
    //     4) returns 的引用类型返回值一般用 memory
    // ═════════════════════════════════════════════════════════════════════

    /// 演示 calldata：外部传入的数组只读、最省 gas
    function setNumbers(uint256[] calldata _numbers) external {
        // 不能写 _numbers[0] = 1; 因为 calldata 是只读的
        numbers = _numbers;     // 这一步会把 calldata 拷贝进 storage
    }

    /// 演示 memory：在函数里临时构造一个数组返回
    function buildSquaredArray(uint256 n) external pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](n);   // 在 memory 里 new
        for (uint256 i = 0; i < n; i++) {
            arr[i] = i * i;
        }
        return arr;
    }

    /// 演示 storage 引用："拿到 storage 的指针，改它就是改链上数据"
    function incrementFirstUserScore() external {
        require(users.length > 0, "no users");
        User storage u = users[0];   // u 是指向 storage 里 users[0] 的指针
        u.score += 1;                // 这一步真的改了链上数据
    }

    /// 演示 memory 拷贝：和上面对比，改的是 memory 里的副本，根本不会影响链上
    function tryIncrementFirstUserScoreInMemory() external view returns (uint256) {
        require(users.length > 0, "no users");
        User memory u = users[0];    // 这里把 storage 复制了一份到 memory
        u.score += 1;                // 改的只是 memory 副本
        return u.score;              // 真正的 users[0].score 还是原值，没变！
        // ⚠️ 这是新手最容易踩的坑：以为改了状态，其实只改了内存副本。
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 7】mapping + struct + 数组组合：典型业务建模
    // ═════════════════════════════════════════════════════════════════════

    function addUser(string calldata nickname) external {
        users.push(User({
            nickname: nickname,
            score: 0,
            active: true
        }));
    }

    function userCount() external view returns (uint256) {
        return users.length;
    }

    function deposit() external payable {
        // msg.value：本次调用附带的 wei
        balanceOf[msg.sender] += msg.value;
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 8】可见性深入：external vs public 的 gas 差异
    //
    //   • external 函数：参数从 calldata 读，省 gas
    //   • public   函数：编译器会生成"内部跳转"代码，方便合约内部调用
    //
    //   规则：如果一个函数永远只会被合约外部调用，写 external 比 public 省 gas。
    // ═════════════════════════════════════════════════════════════════════

    /// internal 函数：本合约 + 子合约可用
    function _double(uint256 x) internal pure returns (uint256) {
        return x * 2;
    }

    /// 暴露一个 external 接口给外部调用
    function doubleIt(uint256 x) external pure returns (uint256) {
        return _double(x);
    }

    /// private 工具函数：只能本合约用，连子合约都不行
    function _isOwner(address who) private view returns (bool) {
        return who == owner;
    }

    /// 演示 private 的"边界"
    function isCallerOwner() external view returns (bool) {
        return _isOwner(msg.sender);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎓 本文件涵盖的 8 个知识点：
//   1. 值类型 vs 引用类型 + 默认值
//   2. 可见性 public / external / internal / private
//   3. enum 枚举
//   4. 数组 / string / struct / mapping
//   5. 构造函数
//   6. storage / memory / calldata 三大数据位置
//   7. mapping + struct + 数组的组合用法（含 payable）
//   8. external vs public 的 gas 差异 + private 边界
//
// 下一步：去看 TypesDemo.t.sol，从测试里验证这些知识点。
// ─────────────────────────────────────────────────────────────────────────────
