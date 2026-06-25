# L2 · 数据类型、可见性、数据位置

> 本节课目标：建立学员对 Solidity **类型系统**的肌肉记忆，并搞清最容易踩坑的 **storage / memory / calldata** 三大数据位置。

---

## 🎯 课程目标

学完本节课，学员可以：

1. 列出 Solidity 的 **值类型** vs **引用类型** 各有哪些；
2. 在写函数时**正确选择** `public` / `external` / `internal` / `private`；
3. 解释清楚 `storage` / `memory` / `calldata` 三者的区别和使用场景；
4. 看到一段陌生 Solidity 代码，能说出每个变量"住"在哪里、谁能读、谁能写。

---

## 🗂️ 本课文件夹结构

```
lessons/L2/
├── README.md           ← 课程大纲（你正在看的）
├── TypesDemo.sol       ← 主合约，所有知识点都写在代码注释里
├── TypesDemo.t.sol     ← 测试，从测试角度验证理解
└── TypesDemo.s.sol     ← 部署脚本
```

---

## 📚 知识点地图

```
Solidity 类型系统
├── 值类型（赋值即复制）
│   ├── bool
│   ├── uintN / intN  (N = 8, 16, ..., 256)
│   ├── address / address payable
│   ├── bytesN  (定长，1..32)
│   └── enum
└── 引用类型（赋值即引用，需指定数据位置）
    ├── string / bytes  (动态)
    ├── 数组（定长 T[N] / 动态 T[]）
    ├── mapping(K => V)
    └── struct

可见性
├── public    (外部+内部都可调用，自动生成 getter)
├── external  (只能外部调用，省 gas)
├── internal  (本合约+子合约可调用)
└── private   (只能本合约调用)

数据位置（仅引用类型需要明确）
├── storage   (永久存在链上，写要花 gas)
├── memory    (函数执行期间的临时内存，函数返回后销毁)
└── calldata  (外部调用的原始入参区，只读 + 最省 gas)
```

---

## 🧠 速查表：uintN / intN / bytesN 的命名与取值

> `uintN` 的 N 是**位数（bit）**，`bytesN` 的 N 是**字节数（byte）**。1 byte = 8 bit。

### 命名规则对比

| 类型 | N 的含义 | N 的取值 | 步长 | 共几种 |
|---|---|---|---|---|
| `uintN` / `intN` | **位数（bit）** | 8, 16, 24, 32, ..., 248, 256 | 每次 +8 | 32 种 |
| `bytesN` | **字节数（byte）** | 1, 2, 3, 4, ..., 31, 32 | 每次 +1 | 32 种 |

### 常用类型及等价大小

| uint 类型 | = 多少字节 | 等价 bytes 类型 | 常见用途 |
|---|---|---|---|
| `uint8` | 1 字节 | `bytes1` | 小数字、enum 底层 |
| `uint16` | 2 字节 | `bytes2` | — |
| `uint32` | 4 字节 | `bytes4` | 函数选择器（selector） |
| `uint160` | 20 字节 | `bytes20` | address 的本质大小 |
| `uint256` | 32 字节 | `bytes32` | 默认整数 / 哈希值 |

### 注意区分：定长 `bytesN` vs 动态 `bytes`

| 名称 | 长度 | 分类 | 需要声明数据位置？ |
|---|---|---|---|
| `bytes32` | 固定 32 字节 | **值类型** | 不需要 |
| `bytes` | 可变长度 | **引用类型** | 必须（memory/calldata/storage） |
| `string` | 可变长度 | **引用类型** | 必须（本质是 UTF-8 的 `bytes`） |

### 一句话记忆

> **`uint` 按 bit 命名，`bytes` 按 byte 命名；`uintN` = `bytes(N/8)`，大小相同只是语义不同。**

---

## 🧠 速查表：address 类型赋值规则

> Solidity 类型系统很严格，**整数和地址是不同类型，不能隐式转换**。

### 什么时候需要 `address(...)`？

| 写法 | 能否直接赋给 address | 原因 |
|---|---|---|
| `0xAb5801c7D97B62f2dF7B6eCdaaD9A4d8f2A57c8`（40位+校验和） | ✅ 可以 | 编译器识别为地址字面量 |
| `0xABC`（不满40位） | ❌ 不行 | 编译器当作整数，需要 `address(...)` |
| `address(0)` | ✅ 可以 | 显式转换，零地址 |
| `address(0xA11CE)` | ✅ 可以 | 显式转换，前面自动补零到20字节 |

```solidity
// ✅ 完整 40 位 + EIP-55 校验和大小写 → 编译器认为这就是地址
address user = 0xAb5801c7D97B62f2dF7B6eCdaaD9A4d8f2A57c8;

// ❌ 不满 40 位 → 编译器当作整数，报错
address alice = 0xA11CE;

// ✅ 显式转换，测试里最常见的简写
address alice = address(0xA11CE);
address dead  = address(0xDEAD);
address zero  = address(0);
```

### 一句话记忆

> **不满 40 位十六进制的数在 Solidity 眼里是整数不是地址，必须用 `address(...)` 做显式类型转换。**

---

## ⏱️ 课堂节奏（2 小时）

| 阶段 | 时长 | 内容 |
|---|---|---|
| ① 复习 L1 + 引入类型系统 | 15 min | 区块链没有 GC，所以"数据放在哪"非常重要 |
| ② 逐段讲 TypesDemo.sol | 50 min | 8 个知识点 + 默认值表 |
| ③ 跑测试 + 看断言 | 30 min | `FOUNDRY_PROFILE=l2 forge test -vv` |
| ④ storage / memory / calldata 三连问 | 20 min | 用 -vvvv 看实际 gas 差异 |
| ⑤ Q&A + 课后作业 | 5 min | |

---

## 🚀 跑通命令（在工程根目录）

```shell
# 编译
FOUNDRY_PROFILE=l2 forge build

# 测试
FOUNDRY_PROFILE=l2 forge test -vv

# 部署到本地链（先开 anvil）
FOUNDRY_PROFILE=l2 forge script TypesDemo.s.sol:TypesDemoScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

---

## 🧠 速查表：什么时候需要声明数据位置？

> **核心原则：只有引用类型才需要声明数据位置，值类型不需要也不允许。**

### 值类型 vs 引用类型的数据位置规则

| 类型分类 | 需要声明数据位置？ | 原因 |
|---|---|---|
| 值类型（`uint` / `bool` / `address` / `enum` / `bytesN`） | **不需要，也不允许** | 赋值即复制，没有歧义 |
| 引用类型（`string` / `bytes` / 数组 / `struct`） | **必须声明** | 赋值可能复制也可能引用，编译器要知道"住在哪" |
| `mapping` | 只能是 `storage` 状态变量 | 不能出现在函数局部变量 |

```solidity
contract Example {
    uint256 public counter;          // ✅ 值类型状态变量，不用写 storage
    string public name;              // ✅ 引用类型状态变量，自动 storage，不用写

    function foo(uint256 x) external {
        uint256 y = x + 1;           // ✅ 值类型局部变量，不用写
        bool flag = true;            // ✅ 同上
        // uint256 memory z = 1;     // ❌ 编译报错！值类型不能标注数据位置
    }
}
```

### 引用类型在不同位置的数据位置选择

| 位置 | 可选数据位置 | 说明 |
|---|---|---|
| 合约状态变量 | 自动 `storage` | 不需要写 |
| 函数体内部局部变量 | `memory` / `storage` | **不能用 `calldata`** |
| `external` 函数参数 | `calldata` / `memory` / `storage` | 推荐 `calldata`（最省 gas、只读） |
| `public` 函数参数 | `memory` / `storage` | 一般不用 `calldata` |
| `internal/private` 函数参数 | `memory` / `storage` | 通常 `memory` |
| 返回值（引用类型） | `memory` / `storage` | 通常 `memory` |

```solidity
function example(uint256[] calldata input) external {
    // ✅ memory：函数内部临时变量
    uint256[] memory temp = new uint256[](3);

    // ✅ storage：指向已有的 storage 数据
    User storage u = users[0];

    // ❌ 非法：calldata 不能用于函数体内部声明的局部变量
    // uint256[] calldata invalid = input;
}
```

### 一句话记忆

> **值类型赋值永远是复制，编译器不需要你说"住在哪"；引用类型可能是复制也可能是引用，必须告诉编译器。`calldata` 是外部传进来的原始数据区，只能出现在函数入口参数里。**

### ⚠️ storage 指针只能指向自己合约内的状态变量

> 每个合约有自己**独立的 storage 空间**，合约 A 无法直接访问合约 B 的 storage 槽位。

```solidity
// ❌ 错误：不能把外部合约的 mapping 赋值给本地 storage 变量
mapping(address => uint256) storage scores = demo.scores();  // 编译报错！

// ✅ 正确：通过 getter 函数调用，让对方合约帮你读
uint256 result = demo.scores(alice);  // demo 自己读自己的 storage，把值返回给你
```

**规则：**
- `storage` 引用 = 指向**当前合约自己的** storage 槽位的指针
- 跨合约只能通过**函数调用（外部消息）**让对方帮你读/写
- `public mapping` 自动生成的 getter 签名：`mappingName(keyType) returns (valueType)`，必须传入 key

```solidity
// ✅ 在自己合约内部可以用 storage 指针
contract TypesDemo {
    mapping(address => uint256) public scores;

    function check(address user) internal view returns (uint256) {
        mapping(address => uint256) storage s = scores;  // ✅ 指向自己的 storage
        return s[user];
    }
}
```

---

## 🧠 速查表：Solidity 声明中各关键字的书写顺序

> 写 Solidity 时最容易搞混的就是"关键字该按什么顺序写"。下面是四大声明场景的固定顺序。

### 1. 状态变量（State Variable）

```
类型  可见性  [constant | immutable]  变量名
```

```solidity
uint256  public              myVar;
uint256  public  constant    MAX = 100;
address  private immutable   admin;
User[]   public              users;
```

### 2. 函数参数（Function Parameter）

```
类型  [memory | calldata | storage]  参数名
```

```solidity
uint256[]  calldata  _numbers
string     memory    _name
User       storage   _user
```

> 值类型参数（`uint256`、`bool`、`address` 等）不写数据位置。

### 3. 局部变量（Local Variable）

```
类型  [memory | storage]  变量名
```

```solidity
uint256[]  memory   arr = new uint256[](10);
User       storage  u   = users[0];
```

> 局部变量不能用 `calldata`。值类型局部变量不写数据位置。

### 4. 函数声明（Function Declaration）

```
function 函数名(参数列表)
    可见性(public | external | internal | private)
    [状态修饰(pure | view | payable)]
    [modifier1] [modifier2] ...
    [virtual | override]
    [returns (返回类型列表)]
{ ... }
```

> **函数状态修饰的四种级别（从严到松）：**
>
> | 修饰符 | 能读状态？ | 能写状态？ | 能收 ETH？ | 是否需要写？ |
> |---|---|---|---|---|
> | `pure` | ❌ | ❌ | ❌ | 必须写 |
> | `view` | ✅ | ❌ | ❌ | 必须写 |
> | （不写，默认 nonpayable） | ✅ | ✅ | ❌ | 不写就是它 |
> | `payable` | ✅ | ✅ | ✅ | 必须写 |
>
> 不写任何状态修饰符 = **默认 nonpayable**：可以读写状态，但拒绝接收 ETH。
>
> **⚠️ `view` / `pure` 是全局承诺，不是只管自己的合约：**
>
> `view` = 整个执行链路中**任何合约的状态都不会被改变**（包括外部合约的 storage、event、ETH 转账等）。
> 所以在 `view` 函数里调用一个非 `view`/`pure` 的外部函数，编译器会直接报错。
>
> ```solidity
> // ❌ 编译报错：addScore 会写外部合约的 storage
> function testAddScore() public view {
>     demo.addScore(alice, 100);   // addScore 不是 view/pure → 不允许
> }
>
> // ✅ 正确：去掉 view
> function testAddScore() public {
>     demo.addScore(alice, 100);
>     assertEq(demo.scores(alice), 100);
> }
> ```

```solidity
// 基础示例
function foo(uint256 x)
    external
    pure
    virtual
    returns (uint256)
{ ... }

// 带 modifier 示例（L3 会详细讲）
function vipIncrement()
    external
    onlyWhitelisted       // ← modifier1
    whenNotPaused         // ← modifier2
{ ... }
```

> modifier（自定义修饰符）放在**状态修饰之后、virtual/override 之前**。
> 多个 modifier 从左到右依次执行。详见 L3 课程。

### 5. 事件 & 错误（Event / Error）

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
error InsufficientBalance(uint256 available, uint256 required);
```

### 速记口诀

> - **状态变量** → 类型 → 可见性 → [不可变修饰] → 名称
> - **函数参数** → 类型 → [数据位置] → 名称
> - **函数声明** → 名称 → 可见性 → 状态修饰 → [modifier] → [override] → returns

---

## 📝 课后作业

1. 在 `TypesDemo.sol` 里再加一个 `mapping(address => uint256) public scores`，写一个 `addScore(address, uint256)` 函数。
2. 给它写测试：两个地址各自 `addScore`，互不影响。
3. 把 `setNumbers` 的参数从 `calldata` 改成 `memory`，跑一遍 `forge test --gas-report`，对比 gas 差异。
4. 把对比结果发到学习群（截图）。

---

## 🧠 一句话总结

> **值类型直接拷贝，引用类型必须告诉编译器"住在哪"**；选错数据位置不仅多花 gas，还可能改不到你以为改的那个变量。
