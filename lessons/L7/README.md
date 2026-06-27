# L7 · Library 与高级语法

> 本节课目标：掌握 Solidity 的代码复用利器 Library，以及 ABI 编解码、自定义值类型、try/catch 等高级语法特性。

---

## 🎯 课程目标

学完本节课，学员可以：

1. 定义和使用 **Library**（数学库、数组库、字符串库）；
2. 用 **using for** 语法糖给类型"装上"扩展方法；
3. 理解 Library 函数 **internal vs public** 的部署区别；
4. 掌握 **struct 高级用法**（嵌套、storage pointer）；
5. 使用 **自定义值类型**（type...is）做编译期类型安全；
6. 熟练使用 **ABI 编解码**（encode / decode / encodePacked）；
7. 理解**函数选择器**的计算和用途；
8. 使用 **try/catch** 捕获外部调用错误。

---

## 🗂️ 本课文件夹结构

```
lessons/L7/
├── README.md                 ← 课程大纲（你正在看的）
├── LibraryAdvanced.sol       ← 主合约：3 个 Library + 主合约 + TryCatchDemo
├── LibraryAdvanced.t.sol     ← 测试：30 个单元测试 + 2 个模糊测试
└── LibraryAdvanced.s.sol     ← 部署脚本
```

---

## 📚 知识点地图

```
L7 · Library & 高级语法
├── Library 基本概念
│   ├── 无状态、无 ETH、不可继承
│   ├── 直接调用：MathLib.add(a, b)
│   └── 附加到类型：a.add(b)
├── using for 语法糖
│   ├── using MathLib for uint256;
│   ├── 第一个参数 = 调用者本身
│   └── 文件级别 vs 合约级别
├── Struct 高级用法
│   ├── 嵌套 struct
│   ├── mapping(address => Struct)
│   └── storage pointer（引用传递）
├── 自定义值类型
│   ├── type USD is uint256;
│   ├── wrap() / unwrap() 转换
│   └── 编译期类型安全，零运行时开销
├── ABI 编解码
│   ├── abi.encode — 标准编码（32字节对齐）
│   ├── abi.encodePacked — 紧凑编码
│   ├── abi.decode — 解码
│   ├── abi.encodeWithSignature — 构造 calldata
│   └── keccak256(abi.encodePacked(...)) — 哈希
├── 函数选择器
│   ├── keccak256("func(type)") 前 4 字节
│   ├── this.func.selector
│   └── type(Interface).interfaceId
├── try/catch
│   ├── catch Error(string) — require/revert
│   ├── catch Panic(uint) — assert/除零
│   └── catch (bytes) — 自定义 error
└── 编译期常量
    ├── constant + keccak256
    └── constant + bytes4(...)
```

---

## ⏱️ 课堂节奏（2 小时）

| 阶段 | 时长 | 内容 |
|---|---|---|
| ① 复习 L6 + 引入"代码怎么优雅复用" | 10 min | Library 解决什么问题？ |
| ② 逐段讲 LibraryAdvanced.sol | 50 min | 8 个知识点 + Java/Kotlin 类比 |
| ③ 跑测试 + 讲解 ABI 编解码 | 30 min | `FOUNDRY_PROFILE=l7 forge test -vv` |
| ④ 动手练：写一个 AddressLib | 15 min | isContract / toChecksumString |
| ⑤ Q&A + 课后作业 | 15 min | |

---

## 🚀 跑通命令（在工程根目录）

```shell
# 编译
FOUNDRY_PROFILE=l7 forge build

# 测试
FOUNDRY_PROFILE=l7 forge test -vv

# 部署到本地链（先开 anvil）
FOUNDRY_PROFILE=l7 forge script LibraryAdvanced.s.sol:LibraryAdvancedScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

---

## 🧠 速查表：Library vs Contract

| 特性 | Library | Contract |
|---|---|---|
| 状态变量 | ❌ 不能有 | ✅ 可以有 |
| 接收 ETH | ❌ 不能 | ✅ 可以（payable） |
| 继承 | ❌ 不能继承也不能被继承 | ✅ 可以 |
| 部署 | internal 函数不部署（内联） | 必须部署 |
| using for | ✅ 可以附加到类型 | ❌ 不行 |
| 典型用途 | 工具函数（Math/Array/String） | 业务逻辑 |

---

## 🧠 速查表：using for 语法

```solidity
// 1. 把整个 Library 附加到某个类型
using MathLib for uint256;
uint256 x = 10;
x.add(5);  // ≡ MathLib.add(x, 5)

// 2. 只附加指定函数
using { MathLib.add, MathLib.sub } for uint256;

// 3. 附加到所有类型（不推荐）
using MathLib for *;

// 4. 文件级别（Solidity 0.8.13+）
// 写在文件顶部，作用于整个文件
using MathLib for uint256;
```

---

## 🧠 速查表：ABI 编解码

| 函数 | 用途 | 输出长度 |
|---|---|---|
| `abi.encode(args)` | 标准编码，每参数 32 字节对齐 | 参数数 × 32 字节 |
| `abi.encodePacked(args)` | 紧凑编码，不填充 | 按实际长度拼接 |
| `abi.encodeWithSignature(sig, args)` | 4字节选择器 + 编码参数 | 4 + 参数编码 |
| `abi.decode(data, (types))` | 解码回具体类型 | — |

```solidity
// 编码
bytes memory data = abi.encode(alice, uint256(100));

// 解码
(address addr, uint256 amount) = abi.decode(data, (address, uint256));

// 哈希（常用于签名、Merkle Tree）
bytes32 hash = keccak256(abi.encodePacked(addr, nonce, msg));
```

⚠️ **encodePacked 注意事项**：如果拼接两个动态类型（如两个 string），可能发生哈希碰撞：
```solidity
// "ab" + "c" 和 "a" + "bc" 的 encodePacked 结果相同！
keccak256(abi.encodePacked("ab", "c")) == keccak256(abi.encodePacked("a", "bc"))
// 解决：在中间加一个固定分隔符，或者用 abi.encode
```

---

## 🧠 速查表：函数选择器

| 获取方式 | 示例 |
|---|---|
| 手动计算 | `bytes4(keccak256("transfer(address,uint256)"))` |
| 编译器自动 | `this.transfer.selector` |
| 接口 ID | `type(IERC20).interfaceId`（所有函数选择器 XOR） |
| 常量定义 | `bytes4 constant SEL = 0xa9059cbb;` |

---

## 🧠 速查表：try/catch

| catch 分支 | 捕获什么 | 触发条件 |
|---|---|---|
| `catch Error(string memory reason)` | require / revert with string | `require(false, "msg")` |
| `catch Panic(uint errorCode)` | 内部错误 | assert 失败、除零、溢出 |
| `catch (bytes memory data)` | 所有其他错误 | 自定义 error、低级 revert |

常见 Panic 错误码：

| 错误码 | 含义 |
|---|---|
| 0x01 | assert 失败 |
| 0x11 | 算术溢出/下溢 |
| 0x12 | 除以零 |
| 0x21 | 枚举类型转换无效 |
| 0x32 | 数组越界 |

---

## 📝 课后作业

1. **实践题**：写一个 `AddressLib` library，包含 `isContract(address)` 函数（用 `addr.code.length > 0` 判断），用 using for 附加到 address 类型，写测试验证。
2. **实践题**：用 `abi.encodePacked` 构造两组不同输入但哈希相同的例子，验证哈希碰撞，然后改用 `abi.encode` 证明不再碰撞。
3. **思考题**：为什么 OpenZeppelin 的 Library 几乎都用 `internal` 函数？`public` Library 函数有什么缺点？
4. **拓展题**：用 try/catch 包装一个"安全的 ERC20 transfer"函数，失败时返回 false 而非 revert。

---

## 🧠 一句话总结

> **Library = 零状态的工具箱；using for = 给类型装扩展方法；abi.encode = 序列化协议；try/catch = 优雅地处理外部调用失败。这些是写生产级合约的必备高级武器。**
