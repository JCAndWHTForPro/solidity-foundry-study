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

## ❓ 常见疑问解答

### Q1: Solidity 的异常分类有哪些？

Solidity 中所有异常的本质都是 **revert**（回滚交易状态），按来源和编码方式分为三大类：

| 类型 | 触发方式 | ABI 编码 | 典型场景 |
|------|---------|----------|----------|
| **Error(string)** | `require(cond, "msg")` / `revert("msg")` | `abi.encodeWithSignature("Error(string)", msg)` | 输入校验、权限检查 |
| **Panic(uint256)** | `assert(false)` / 编译器自动插入 | `abi.encodeWithSignature("Panic(uint256)", code)` | 内部不变量违反、数学溢出 |
| **Custom Error** | `revert MyError(...)` | `abi.encodeWithSelector(MyError.selector, ...)` | 省 gas 的结构化错误（0.8.4+） |

还有第四种：**空 revert**（`revert()` 或 transfer 失败），无数据。

---

### Q2: Panic 错误码完整对照表

| Panic Code | 含义 | 触发场景 |
|-----------|------|----------|
| `0x00` | 通用 panic | 编译器插入的通用断言 |
| `0x01` | assert 失败 | `assert(false)` |
| `0x11` | 算术溢出/下溢 | `uint8(255) + 1`（0.8+ 默认检查） |
| `0x12` | 除以零 | `x / 0` 或 `x % 0` |
| `0x21` | 枚举越界 | 转换到不存在的枚举值 |
| `0x22` | 存储编码错误 | 访问损坏的 storage |
| `0x31` | pop 空数组 | `arr.pop()` 但数组为空 |
| `0x32` | 数组越界 | `arr[100]` 但 length=5 |
| `0x41` | 内存分配过大 | `new uint[](2**64)` |
| `0x51` | 未初始化函数指针 | 调用未赋值的 internal 函数变量 |

---

### Q3: require / revert / assert 该怎么选？

| 关键字 | 用途 | 剩余 gas | 推荐场景 |
|--------|------|---------|----------|
| `require(cond, "msg")` | 校验外部输入/前置条件 | 退还剩余 gas | 参数校验、权限、余额检查 |
| `revert CustomError()` | 同上，但更省 gas | 退还剩余 gas | **推荐替代 require** |
| `assert(cond)` | 检查内部不变量 | 退还剩余 gas（0.8+） | 不应该发生的情况 |

```solidity
// require — 检查用户输入
require(amount > 0, "Zero amount");

// Custom Error — 更省 gas 的方式（推荐）
error ZeroAmount();
if (amount == 0) revert ZeroAmount();

// assert — 检查内部逻辑不变量
assert(totalSupply == sumOfAllBalances);  // 如果失败说明有 bug
```

---

### Q4: try/catch 能捕获内部函数的异常吗？

**不能。** try/catch 只能用于 **外部调用**（包括 `this.func()` 自调用）：

```solidity
// ✅ 可以 catch — 外部调用
try externalContract.foo() returns (uint result) {
    // 成功
} catch Error(string memory reason) {
    // require/revert("msg")
} catch Panic(uint code) {
    // assert 失败、溢出、越界
} catch (bytes memory data) {
    // Custom Error、空 revert
}

// ❌ 不能 catch — 内部调用
// try internalFunc() { ... }  // 编译报错！

// ✅ 变通：用 this 变成外部调用（会消耗更多 gas）
try this.myFunc() { ... } catch { ... }
```

**关键区别**：内部函数的异常会直接冒泡（bubble up），无法在同一合约内拦截。

---

### Q5: 和传统语言（Java/Python）的异常处理有什么区别？

| 特性 | Java/Python | Solidity |
|------|------------|----------|
| 异常类型 | 丰富的异常类继承体系 | 只有 3 种编码格式 |
| 能 catch 吗 | 随时 try/catch | 只能 catch **外部调用** |
| 内部函数异常 | 可以 catch | **不能 catch，直接冒泡** |
| 异常后状态 | 取决于代码（可能半修改） | **整个调用链状态回滚** |
| 性能代价 | 栈展开 | gas 消耗 |
| 推荐做法 | 能 catch 就 catch | 尽量在入口就 require 检查 |

> **Solidity 哲学：与其 catch 异常再修复，不如在入口用 require 严格校验，不满足条件就直接回滚。**

---

### Q6: `uint[] memory arr;` 声明动态数组的默认值是什么？

声明但不初始化时，是一个**长度为 0 的空数组**：

```solidity
uint[] memory arr;
// arr.length == 0
// 不能直接 arr[0] = 1（会越界 revert）
```

正确初始化方式：

```solidity
// 用 new 指定长度（元素全为默认值 0）
uint[] memory arr = new uint[](5);
// arr.length == 5, arr[0]~arr[4] 全为 0

// 从 storage 数组深拷贝
uint[] memory copy = storageArray;
```

各类型元素的默认值：

| 类型 | 默认值 |
|------|--------|
| `uint[]` | 元素全为 `0` |
| `bool[]` | 元素全为 `false` |
| `address[]` | 元素全为 `address(0)` |

---

### Q7: memory 数组都是定长的吗？和 storage 数组有什么区别？

**是的，memory 数组一旦创建长度就固定了，不能增删。** 但有两种"固定"方式：

| 声明方式 | 长度何时确定 | 能否用变量定长度 |
|---------|------------|----------------|
| `uint[5] memory arr` | **编译时**确定，永远是 5 | 不能 |
| `uint[] memory arr = new uint[](n)` | **运行时**确定，取决于 n | 可以 |

```solidity
function example(uint size) external pure {
    uint[3] memory fixed3;                    // 编译时定长
    uint[] memory dynamic = new uint[](size); // 运行时定长
    
    // 两者创建后都不能 push/pop
    // fixed3.push(1);   ❌
    // dynamic.push(1);  ❌
}
```

**Storage vs Memory 数组能力对比：**

| 操作 | storage 数组 | memory 数组 |
|------|-------------|------------|
| 声明位置 | 合约状态变量 | 函数内部 |
| 生命周期 | 永久（链上） | 函数执行期间 |
| `push(x)` | ✅ 长度 +1 | ❌ 不可以 |
| `pop()` | ✅ 长度 -1 | ❌ 不可以 |
| 动态改长度 | ✅ 可以 | ❌ 不可以 |
| `arr[i] = x` | ✅ | ✅ |
| Gas 成本 | 贵（写 ~20000 gas） | 便宜 |

> **总结：memory 数组本质上都是"定长"的，`uint[]` 只是允许在运行时决定长度是多少，一旦 `new` 出来就锁死。真正能动态增删的只有 storage 数组的 push/pop。**

---

## 📝 课后作业

1. **实践题**：写一个 `AddressLib` library，包含 `isContract(address)` 函数（用 `addr.code.length > 0` 判断），用 using for 附加到 address 类型，写测试验证。
2. **实践题**：用 `abi.encodePacked` 构造两组不同输入但哈希相同的例子，验证哈希碰撞，然后改用 `abi.encode` 证明不再碰撞。
3. **思考题**：为什么 OpenZeppelin 的 Library 几乎都用 `internal` 函数？`public` Library 函数有什么缺点？
4. **拓展题**：用 try/catch 包装一个"安全的 ERC20 transfer"函数，失败时返回 false 而非 revert。

---

## 🧠 一句话总结

> **Library = 零状态的工具箱；using for = 给类型装扩展方法；abi.encode = 序列化协议；try/catch = 优雅地处理外部调用失败。这些是写生产级合约的必备高级武器。**
