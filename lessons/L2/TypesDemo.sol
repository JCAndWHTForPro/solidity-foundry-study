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
    //     局部变量不需要也不允许声明数据位置，默认直接放在 EVM 栈（stack）上
    //     （必要时编译器会借助 memory，但语法层面不能写 memory/storage/calldata）。
    //     特点：赋值即「复制」，互不影响。
    //
    //     手动初始化示例：
    //       bool    active = true;
    //       uint256 count  = 0;          // 或 uint8 small = 255;
    //       int256  delta  = -100;
    //       address owner  = address(0);  // 空地址
    //       address user   = 0xAb5801c7D97B62f2dF7B6eCdaaD9A4d8f2A57c8;
    //       bytes32 hash   = keccak256(abi.encodePacked("hello"));
    //       bytes4  sig    = 0x70a08231;
    //       Status  s      = Status.Pending;
    //
    //   ▶ 引用类型：string / bytes / 数组 / mapping / struct
    //     特点：赋值可能「共享底层数据」，必须告诉编译器「住在哪」。
    //
    //     手动初始化示例：
    //       string memory str = "hello";        // UTF-8 字符串
    //       bytes  memory b   = hex"1234";      // 动态字节数组
    //       uint256[] memory arr = new uint256[](3);   // 动态数组，初始长度 3
    //       uint256[3] memory fixedArr = [uint256(1), 2, 3]; // 定长数组
    //       User memory u = User({nickname: "alice", score: 100, active: true});
    //       mapping(address => uint256) public balance;      // mapping 只能作为 storage 状态变量，不能作为局部变量用 new 初始化
    //
    //     局部变量必须显式声明数据位置：
    //       memory  / calldata  / storage（仅当指向已有状态变量时）
    //
    //   ▶ Solidity 没有 null / undefined，所有变量都有"默认值"：
    //       bool      → false
    //       uint/int  → 0
    //       address   → address(0)  （类型等价于 bytes20，默认全 0）
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
    bool   public flag;          // 状态变量默认就在 storage 中，不能也不需显式声明 storage
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
    // ─────────────────────────────────────────────────────────────────
    // 【补充】Solidity 声明中各关键字的书写顺序
    //
    // ┌─ 状态变量（State Variable）──────────────────────────────┐
    // │  类型  可见性  [constant | immutable]  变量名             │
    // │                                                          │
    // │  示例：                                                   │
    // │    uint256  public              myVar;                   │
    // │    uint256  public  constant    MAX = 100;               │
    // │    address  private immutable   admin;                   │
    // │    User[]   public              users;                   │
    // └──────────────────────────────────────────────────────────┘
    //
    // ┌─ 函数参数（Function Parameter）──────────────────────────┐
    // │  类型  [memory | calldata | storage]  参数名              │
    // │                                                          │
    // │  示例：                                                   │
    // │    uint256[]  calldata  _numbers                         │
    // │    string     memory    _name                            │
    // │    User       storage   _user                            │
    // └──────────────────────────────────────────────────────────┘
    //
    // ┌─ 局部变量（Local Variable）──────────────────────────────┐
    // │  类型  [memory | storage | calldata]  变量名              │
    // │                                                          │
    // │  示例：                                                   │
    // │    uint256[]  memory   arr = new uint256[](10);          │
    // │    User       storage u  = users[0];                     │
    // └──────────────────────────────────────────────────────────┘
    //
    // ┌─ 函数声明（Function Declaration）────────────────────────┐
    // │  function 函数名(参数列表)                                │
    // │      可见性(public|external|internal|private)            │
    // │      [状态修饰(pure|view|payable)]                       │
    // │      [virtual | override]                                │
    // │      [returns (返回类型列表)]                             │
    // │                                                          │
    // │  示例：                                                   │
    // │    function foo(uint256 x)                               │
    // │        external                                          │
    // │        pure                                              │
    // │        virtual                                           │
    // │        returns (uint256)                                 │
    // │    { ... }                                               │
    // └──────────────────────────────────────────────────────────┘
    //
    // ┌─ 事件 & 错误（Event / Error）────────────────────────────┐
    // │  event  事件名(类型 [indexed] 参数名, ...)               │
    // │  error  错误名(类型 参数名, ...)                          │
    // │                                                          │
    // │  示例：                                                   │
    // │    event Transfer(address indexed from, address indexed to, uint256 value); │
    // │    error InsufficientBalance(uint256 available, uint256 required);         │
    // └──────────────────────────────────────────────────────────┘
    //
    // 💡 速记口诀：
    //    状态变量 → 类型 → 可见性 → [不可变修饰] → 名称
    //    函数参数 → 类型 → [数据位置] → 名称
    //    函数声明 → 名称 → 可见性 → 状态修饰 → [override] → returns
    // ─────────────────────────────────────────────────────────────────

    User[] public users;

    // mapping：key-value 映射
    //   • mapping 没有 length，不可遍历；
    //   • 没插入过的 key，读出来是 value 类型的默认值；
    //   • mapping 必须放在 storage，原因如下：
    //     1) mapping 没有连续的内存布局，它通过 keccak256(key, slot) 直接定位 storage 槽位；
    //     2) memory 中的数据需要已知长度、可线性拷贝，而 mapping 无法被整体复制或分配；
    //     3) 因此 mapping 只能作为状态变量存在，不能声明为 memory 局部变量。
    // mapping 的 key 不限于 address，任何值类型都可以作为 key：
    //   address、uint256、bytes32、enum、bool 等都合法；
    //   但不能是 mapping、动态数组、string、bytes 或包含它们的 struct。
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => User) public userById;      // uint256 作为 key
    mapping(bytes32 => bool) public usedHash;      // bytes32 作为 key


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
    //     1) 状态变量就是声明在合约里、不在函数里的变量（public/internal/private 都行），
    //        它们永远自动存在 storage，不用写 storage
    //     2) 函数里的引用类型局部变量必须显式 memory 或 storage
    //        • memory：在函数执行期间新建一个"副本"，函数结束后消失
    //        • storage：不是一个新变量，而是「指向已有状态变量的引用/指针」
    //          例如 User storage u = users[0]; 中 u 就是 users[0] 的别名，
    //          通过 u.score += 1 修改的其实就是链上 storage 里的真实数据
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
        User storage u = users[0];   // 只创建一个指向已有 storage 数据的引用（指针/别名），
                                     // 本身不向链上写入任何新数据，也不额外占用 storage 槽位。
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
        // ✅ uint256 是「值类型」，没有数据位置（storage / memory / calldata）的概念。
        // 值类型（uint256 / bool / address 等）赋值即复制，不需要标注数据位置。
        // 运行时它们通常直接放在 EVM 栈上，或被打包进函数执行所需的内存区域；
        // 但 uint256 是「值类型」，语法上不能也不允许标注 storage / memory / calldata。
        // 对值类型来说，赋值总是复制一份完整数据，不存在"指向别处"的引用，
        // 所以编译器不需要、也不让你指定数据位置。
        // 只有「引用类型」（数组、struct、string、bytes）才必须显式标注数据位置。
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
