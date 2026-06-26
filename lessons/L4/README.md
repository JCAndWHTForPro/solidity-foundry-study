# L4 · 继承、接口、抽象合约

> 本节课目标：掌握 Solidity 面向对象体系 —— 继承、多态、接口标准、代码复用模式。

---

## 🎯 课程目标

学完本节课，学员可以：

1. 用 `interface` 定义合约标准（类比 Java interface）；
2. 用 `abstract contract` 提供部分实现（类比 Java abstract class）；
3. 用 `is` 实现继承，理解 `virtual` / `override` 重写机制；
4. 掌握**构造函数参数传递**（子调父）；
5. 理解**多重继承**和 C3 线性化顺序；
6. 用 `super` 调用继承链上的函数；
7. 掌握 **internal 函数复用模式**（OpenZeppelin 标准）；
8. 用接口类型做参数实现**多态 / 面向接口编程**。

---

## 🗂️ 本课文件夹结构

```
lessons/L4/
├── README.md              ← 课程大纲（你正在看的）
├── Inheritance.sol        ← 主合约，所有知识点都写在代码注释里
├── Inheritance.t.sol      ← 测试，16 个用例覆盖核心概念
└── Inheritance.s.sol      ← 部署脚本
```

---

## 📚 知识点地图

```
L4 · 继承 & 接口 & 多态
├── 接口（interface）
│   ├── 规则：无状态、无构造函数、全部 external
│   ├── 用途：定义标准（ERC20/ERC721）
│   └── 类比 Java：纯接口（无 default 方法）
├── 抽象合约（abstract contract）
│   ├── 可以有状态变量和构造函数
│   ├── 未实现的函数标注 virtual
│   └── 类比 Java：abstract class
├── 继承（is）
│   ├── 函数重写：virtual → override
│   ├── 继续允许重写：virtual override
│   └── 类比 Java：extends + @Override
├── 构造函数参数传递
│   ├── 写法 1：contract Dog is Animal("name") { }
│   └── 写法 2：constructor() Animal("name") { }
├── 多重继承
│   ├── contract C is A, B { }
│   ├── 从左到右 = 从基础到派生
│   ├── C3 线性化算法
│   └── override(A, B) 显式声明
├── super 关键字
│   ├── 按线性化链调用（不是固定父合约）
│   └── 类比 Python 的 super()
├── internal 函数复用模式
│   ├── external = 薄包装
│   ├── _internalFunc() = 核心逻辑
│   └── OpenZeppelin 标准模式
└── 接口类型做参数 —— 多态
    ├── function foo(IERC20 token) { token.transfer(...) }
    └── 传入任何实现了接口的合约实例
```

---

## ⏱️ 课堂节奏（2 小时）

| 阶段 | 时长 | 内容 |
|---|---|---|
| ① 复习 L3 + 引入"代码复用" | 10 min | 为什么需要继承？modifier 是最简单的复用 |
| ② 逐段讲 Inheritance.sol | 50 min | 8 个知识点 + Java 类比 |
| ③ 跑测试 + 讲解多态调用 | 30 min | `FOUNDRY_PROFILE=l4 forge test -vv` |
| ④ 动手练：写一个 Cat 合约 | 20 min | 继承 Animal，实现 IAnimal |
| ⑤ Q&A + 课后作业 | 10 min | |

---

## 🚀 跑通命令（在工程根目录）

```shell
# 编译
FOUNDRY_PROFILE=l4 forge build

# 测试
FOUNDRY_PROFILE=l4 forge test -vv

# 部署到本地链（先开 anvil）
FOUNDRY_PROFILE=l4 forge script Inheritance.s.sol:InheritanceScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

---

## 🧠 速查表：继承关键字对比

| Solidity | Java | 含义 |
|---|---|---|
| `is` | `extends` / `implements` | 继承 |
| `virtual` | 非 `final`（默认可重写） | 允许被子合约重写 |
| `override` | `@Override` | 重写父合约函数 |
| `virtual override` | — | 重写了但还允许继续被重写 |
| `abstract contract` | `abstract class` | 不能直接部署，可有部分实现 |
| `interface` | `interface`（无 default） | 纯合约标准 |
| `super.foo()` | `super.foo()` | 调用继承链上一层 |

---

## 🧠 速查表：interface vs abstract contract vs contract

| 特性 | interface | abstract contract | contract |
|---|---|---|---|
| 能有状态变量 | ❌ | ✅ | ✅ |
| 能有构造函数 | ❌ | ✅ | ✅ |
| 能有已实现的函数 | ❌ | ✅ | ✅ |
| 能有未实现的函数 | ✅（全部） | ✅（部分） | ❌ |
| 能直接部署 | ❌ | ❌ | ✅ |
| 函数可见性 | 必须 external | 任意 | 任意 |

---

## 🧠 速查表：多重继承注意事项

```solidity
// ✅ 从最基础到最派生，从左到右
contract PetShopV2 is DogV2, Pausable, Countable { }

// ❌ 顺序反了会编译报错
// contract PetShopV2 is Countable, Pausable, DogV2 { }

// 如果多个父合约有同名函数，必须显式 override 所有
function foo() external override(ParentA, ParentB) { }
```

---

## 🧠 深度理解：DogV2 相比 Countable 是更基础还是更派生？

> 这是一个反直觉的核心问题。

### 直觉与现实的冲突

凭直觉我们会认为：
- `Countable` 没有父类，应该更“基础”
- `DogV2` 继承自 `Animal`，应该更“派生”

**但编译器的结论恰恰相反：`DogV2` 是更“基础（Base-like）”的合约，`Countable` 是更“派生（Derived-like）”的合约。**

这就是为什么 `is` 后面 `DogV2` 必须写在左边，`Countable` 必须写在右边。

### 维度一：“肉体与衣服”（架构设计角度）

在面向对象设计中，不能只看“有没有父类”，还要看 **“谁是谁的修饰插件”**。

| 角色 | 合约 | 描述 |
|---|---|---|
| 🦴 **肉体（主干）** | `DogV2` | 提供核心业务逻辑、核心状态变量（名字、声音、speak） |
| 🧥 **衣服（外挂）** | `Pausable`、`Countable` | 只是给主体临时增加的“小功能” |

**编译器的逻辑是：**
- 先声明“肉体”（写在左边 = 基础）
- 再把“衣服”套在肉体外面（写在右边 = 派生）

```solidity
// ✅ 先有狗的肉体，再套上暂停功能，最后套上计数功能
contract PetShopV2 is DogV2, Pausable, Countable { }

// ❌ 先凭空飘着一个计数器和暂停器，然后硬塞一整条狗进去？编译器懵了
contract PetShopV2 is Countable, Pausable, DogV2 { } // 报错!
```

### 维度二：构造函数依赖与重写优先级（技术底层角度）

#### 构造函数传参依赖

| 合约 | 构造函数 | 初始化复杂度 |
|---|---|---|
| `Countable` | 无参（甚至没有构造函数） | 极简 |
| `Pausable` | 无参（只设置 `_pauseAdmin`） | 简单 |
| `DogV2` | **有参**（`_name`, `_sound`），还要传给父合约 `Animal` | 复杂 |

Solidity 中，**有构造函数依赖的、初始化更复杂的合约，属于“底层基石”，必须先被初始化。**

#### “最派生”= 拥有最终重写权

写在右边的合约拥有更高的优先级：

```solidity
function register() external whenNotPaused { ... }
//                           ↑
// whenNotPaused 来自 Pausable。
// Pausable 写在右边，才能作为“切面”去修饰左边 DogV2 的核心逻辑。
```

如果 `Pausable` 写在 `DogV2` 左边（比 DogV2 还基础），那么 DogV2 的逻辑就无法被 `Pausable` 正确地包裹和限制。

### 结论

| 概念 | 含义 | 实例 |
|---|---|---|
| **基础（放左边）** | 核心业务合约、有深层继承链、构造函数要传参 | `DogV2` |
| **派生（放右边）** | 功能性 Mixin、无状态/轻量工具合约、接口 | `Pausable`、`Countable` |

> **虽然 `DogV2` 经历了一次继承，但它是 PetShopV2 的“生命之源（基础）”；而没有父类的 `Countable`，只是一个“临时贴上去的标签（派生外挂）”。**

---

## 📝 课后作业

1. 写一个 `Cat is Animal` 合约，实现 `speak()` 返回 "Meow"，`legs()` 返回 4。写测试验证。
2. 写一个 `Bird is Animal` 合约，`legs()` 返回 2。让 `AnimalChecker.isFourLegged(bird)` 返回 false，写测试验证。
3. 给 `Pausable` 加一个 `event` 记录暂停次数。写测试验证事件触发。
4. 思考题：如果 `DogV2.description()` 没有标 `virtual`，`PetShopV2` 还能重写它吗？为什么？

---

## 🧠 一句话总结

> **interface 定标准，abstract 给模板，is 拿来用；`virtual` 说"我可以被改"，`override` 说"我改了"；internal 函数是继承复用的正确姿势。**
