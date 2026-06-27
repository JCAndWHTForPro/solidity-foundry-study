# L5 · 事件（Events）与 ETH 收发

> 本节课目标：掌握链上日志系统（事件）和以太币的收发机制 —— 这是写任何 DeFi 合约的前置知识。

---

## 🎯 课程目标

学完本节课，学员可以：

1. 定义和触发**事件（event / emit）**；
2. 理解 **indexed 参数**的作用（链上索引/搜索）；
3. 编写 **payable 函数**接收 ETH；
4. 实现 **receive() / fallback()** 处理纯转账和兜底调用；
5. 使用 **msg.value** 和 **address(this).balance** 查询 ETH；
6. 掌握三种**合约向外转账**方式（transfer / send / call）及推荐写法；
7. 熟悉 **ETH 单位**（wei / gwei / ether）；
8. 理解**事件在 DeFi 中的实际作用**。

---

## 🗂️ 本课文件夹结构

```
lessons/L5/
├── README.md              ← 课程大纲（你正在看的）
├── EventsAndETH.sol       ← 主合约，8 个知识点全注释讲义
├── EventsAndETH.t.sol     ← 测试，15 个用例 + 模糊测试
└── EventsAndETH.s.sol     ← 部署脚本
```

---

## 📚 知识点地图

```
L5 · 事件 & ETH 收发
├── 事件系统
│   ├── event 定义 + emit 触发
│   ├── indexed 参数（最多 3 个，可搜索）
│   ├── 非 indexed 参数（data 区域，不可搜索）
│   └── 实际用途：前端监听、The Graph 索引
├── ETH 接收
│   ├── payable 函数（msg.value）
│   ├── receive() external payable —— 纯转账
│   ├── fallback() external payable —— 兜底/不明调用
│   └── 优先级：msg.data 为空 → receive；否则 → fallback
├── ETH 查询
│   ├── msg.value —— 本次调用附带的 ETH
│   ├── address(this).balance —— 合约持有的 ETH
│   └── ETH 单位：1 ether = 1e18 wei
└── ETH 转出
    ├── addr.transfer(amount) —— 2300 gas，不推荐
    ├── addr.send(amount) —— 2300 gas，不推荐
    └── addr.call{value: amount}("") —— ✅ 推荐！
```

---

## ⏱️ 课堂节奏（2 小时）

| 阶段 | 时长 | 内容 |
|---|---|---|
| ① 复习 L4 + 引入"合约怎么收钱发钱" | 10 min | 为什么 ETH 可以直接转给合约？ |
| ② 逐段讲 EventsAndETH.sol | 50 min | 8 个知识点 + 实战注释 |
| ③ 跑测试 + 讲解 vm.expectEmit / vm.deal | 30 min | `FOUNDRY_PROFILE=l5 forge test -vv` |
| ④ 动手练：修改最小存款门槛 | 15 min | 改完跑测试看是否自动失败 |
| ⑤ Q&A + 课后作业 | 15 min | |

---

## 🚀 跑通命令（在工程根目录）

```shell
# 编译
FOUNDRY_PROFILE=l5 forge build

# 测试
FOUNDRY_PROFILE=l5 forge test -vv

# 部署到本地链（先开 anvil）
FOUNDRY_PROFILE=l5 forge script EventsAndETH.s.sol:EventsAndETHScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

---

## 🧠 速查表：事件（Event）

| 概念 | 说明 |
|---|---|
| `event Transfer(address indexed from, address indexed to, uint256 amount)` | 定义事件 |
| `emit Transfer(msg.sender, to, amount)` | 触发事件 |
| `indexed` | 可搜索的索引参数，最多 3 个 |
| 存储位置 | 交易日志（Log），不占 storage |
| Gas 成本 | 约 375 gas/字节（比 SSTORE 20000 gas 便宜得多） |
| 谁能读 | 链下工具（前端 / etherscan / The Graph），合约自己**不能**读 |

```solidity
// 定义
event Deposited(address indexed user, uint256 amount, uint256 timestamp);

// 触发
emit Deposited(msg.sender, msg.value, block.timestamp);
```

---

## 🧠 速查表：ETH 收发

### 接收 ETH

| 场景 | 触发函数 | 条件 |
|---|---|---|
| 调用 payable 函数 + msg.value > 0 | 对应的 payable 函数 | 函数标注 payable |
| 纯 ETH 转账（无 calldata） | `receive()` | 合约有 receive |
| 带 calldata 但函数不存在 | `fallback()` | 合约有 fallback |
| 以上都没有 | 交易 revert | — |

### 转出 ETH

| 方式 | 语法 | Gas 限制 | 失败行为 | 推荐？ |
|---|---|---|---|---|
| transfer | `to.transfer(amount)` | 2300 gas | 自动 revert | ❌ |
| send | `to.send(amount)` | 2300 gas | 返回 false | ❌ |
| **call** | `to.call{value: amount}("")` | 无限制 | 返回 (false, _) | ✅ |

```solidity
// ✅ 推荐写法
(bool success, ) = payable(to).call{value: amount}("");
require(success, "transfer failed");
```

---

## 🧠 速查表：ETH 单位

| 单位 | 等于多少 wei | 常见用途 |
|---|---|---|
| `1 wei` | 1 | 最小单位 |
| `1 gwei` | 1,000,000,000 (10^9) | gas 价格单位 |
| `1 ether` | 1,000,000,000,000,000,000 (10^18) | 人类可读的 ETH 数量 |

```solidity
require(msg.value >= 0.01 ether, "too little");  // 编译时常量
```

---

## 🧠 速查表：Foundry 测试 ETH 相关工具

| 工具 | 用途 | 示例 |
|---|---|---|
| `vm.deal(addr, amount)` | 给地址设置 ETH 余额 | `vm.deal(alice, 10 ether)` |
| `vault.deposit{value: 1 ether}()` | 调用时附带 ETH | — |
| `address(vault).balance` | 查询合约 ETH 余额 | — |
| `vm.expectEmit(true, false, false, true)` | 验证事件触发 | indexed1 匹配 + data 匹配 |

---

# ❓ 常见疑问解答

### Q1: payable 函数「附带 ETH」具体怎么附带？

以太坊交易天然有一个 `value` 字段（和 `to`、`data` 并列），"附带 ETH" 就是填了这个字段。不同场景写法如下：

| 场景 | 写法 |
|---|---|
| Solidity 合约内调用 | `vault.deposit{value: 1 ether}()` |
| 底层 call | `address(vault).call{value: 1 ether}(abi.encodeWithSignature("deposit()"))` |
| Foundry 测试 | `vm.deal(alice, 10 ether); vm.prank(alice); vault.deposit{value: 1 ether}();` |
| 命令行 cast | `cast send <地址> "deposit()" --value 1ether ...` |
| 前端 ethers.js | `contract.deposit({ value: ethers.parseEther("1.0") })` |

> `payable` 关键字的作用：告诉编译器允许 `value > 0` 的调用进来；不加 payable，编译器会自动插入 `require(msg.value == 0)` 的检查。

---

### Q2: calldata 是什么？

**calldata = 调用合约时随交易发送的原始字节数据。**

一笔交易的三个核心字段：

| 字段 | 含义 | 例子 |
|---|---|---|
| `to` | 发给谁 | 0x合约地址 |
| `value` | 附带多少 ETH | 1 ether |
| `data`（calldata） | 调用哪个函数 + 传什么参数 | 编码后的字节 |

例如调用 `vault.deposit(100)` 时，交易的 data 字段为：

```
0xb6b55f25                                                           ← 前4字节 = 函数选择器
0000000000000000000000000000000000000000000000000000000000000064     ← 参数 100 的 ABI 编码
```

纯转 ETH（不调函数）时，data 字段为空。

> `calldata` 作为数据位置关键字时表示"只读的外部输入数据"，比 `memory` 更省 gas。

---

### Q3: msg.data 是什么内置变量？

`msg` 是 Solidity 的全局对象，包含当前调用的元信息：

| 内置变量 | 类型 | 含义 |
|---|---|---|
| `msg.sender` | `address` | 谁发起的调用 |
| `msg.value` | `uint256` | 附带了多少 ETH（wei） |
| `msg.data` | `bytes calldata` | 完整的调用数据（选择器 + 参数） |
| `msg.sig` | `bytes4` | msg.data 的前 4 字节 = 函数选择器 |

EVM 通过 `msg.data` 是否为空来决定走 `receive()` 还是 `fallback()`。

---

### Q4: msg.data 存的是调用者的数据还是被调用者的数据？

**是「别人发给当前合约的调用数据」—— 站在被调用者视角看。**

每一层合约调用都有独立的 `msg` 上下文：

```
外部用户 EOA
  │  msg.data = "doSomething(vault)" 的编码
  ▼
Caller.doSomething()    ← 这里 msg.data 是用户发给 Caller 的
  │  msg.data = "deposit(100)" 的编码
  ▼
Vault.deposit(100)      ← 这里 msg.data 是 Caller 发给 Vault 的
```

 类比快递：`msg.data` = 快递单上写的指令（"请帮我存 100 块"），永远是收件人视角看到的内容。

---

### Q5: 使用 call 转账时，如何执行复杂逻辑？写在哪里？

**复杂逻辑写在接收方的 `receive()` / `fallback()` 或显式 payable 函数里。**

发送方只负责"发钱 + 检查成功"，接收方决定收到钱后做什么：

```
合约 A（发送方）                        合约 B（接收方）
┌─────────────────────┐              ┌───────────────────────────────┐
│ (bool ok,) =        │    call      │ receive() external payable {  │
│   addr.call         │ ──────────►  │     balances[msg.sender] += …│
│   {value: 1 ether}  │              │     _distributeRewards();     │
│   ("");             │              │     emit Deposited(…);        │
│ require(ok);        │              │ }                             │
└─────────────────────┘              └───────────────────────────────┘
```

三种调用方式对应的入口：

| A 怎么调用 | B 的哪个函数被触发 |
|---|---|
| `addr.call{value: 1 ether}("")` | `receive()`（data 为空） |
| `addr.call{value: 1 ether}(abi.encodeWithSignature("deposit()"))` | B 的 `deposit()` 函数 |
| `Vault(addr).deposit{value: 1 ether}()` | B 的 `deposit()` 函数（类型安全，最推荐） |

为什么 `transfer`/`send` 不能做复杂逻辑？因为只给 2300 gas，连一次 SSTORE（20000 gas）都不够。`call` 转发全部剩余 gas，接收方才有资源执行复杂操作。

```solidity
// 接收方写法示例
contract Vault {
    mapping(address => uint256) public balances;

    // 方式 1：receive() 处理纯转账
    receive() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // 方式 2（更推荐）：显式 payable 函数，语义更清晰
    function deposit() external payable {
        require(msg.value >= 0.01 ether, "too little");
        balances[msg.sender] += msg.value;
        _updateStaking(msg.sender);
    }
}
```

> 核心原则：**发送方只管发钱 + 检查返回值，复杂逻辑永远写在接收方。**

---

### Q6: `Vault(addr)` 可以把地址直接转换成合约对象吗？

**是的。Solidity 允许把 `address` 直接类型转换为合约类型。**

```solidity
address addr = 0x1234...;

// 把 address 转换为合约类型
Vault vault = Vault(addr);
vault.deposit{value: 1 ether}();
```

本质：不是"创建合约"，而是告诉编译器"请把这个地址当 Vault 来调用" —— 编译器根据 Vault 的 ABI 自动生成正确的 `msg.data`。

**编译器不会验证**那个地址上是否真的部署了 Vault。如果地址错了，运行时才会 revert。

两种写法的等价关系：

```solidity
// 写法 1：类型转换（推荐，类型安全）
Vault(addr).deposit{value: 1 ether}();

// 写法 2：底层 call（低级，无编译检查）
(bool ok, ) = addr.call{value: 1 ether}(
    abi.encodeWithSignature("deposit()")
);
require(ok);
```

| | 类型转换写法 | 底层 call 写法 |
|---|---|---|
| 类型安全 | 编译期检查函数名、参数类型 | 无检查，写错也能编译 |
| 返回值 | 自动解码 | 需手动 `abi.decode` |
| 失败行为 | 自动 revert + 冒泡错误 | 返回 `(false, ...)` 需手动处理 |

> 类比：`Vault(addr)` 相当于 C 语言的指针类型转换 `(Vault*)addr` —— 告诉编译器"按这个类型来解读"。

---

## 📝 课后作业

1. 把 `deposit()` 的最小存款从 0.001 ether 改为 0.01 ether，跑测试观察哪些 case 会失败，然后修复测试。
2. 给 `withdraw()` 添加一个 `Withdrawn` 事件的测试（用 `vm.expectEmit` 验证事件参数）。
3. 写一个新合约 `Crowdfund`：有目标金额（goal）和截止时间（deadline），超过 deadline 后允许退款。
4. 思考题：为什么 `receive()` 里不建议写太复杂的逻辑？（提示：2300 gas 限制来自 `transfer`/`send`）

---

## 🧠 一句话总结

> **event 是链上合约与链下世界的桥梁；payable + receive 让合约能收钱，call 让合约能发钱；永远用 `call` + 检查返回值，忘掉 `transfer` 和 `send`。**
