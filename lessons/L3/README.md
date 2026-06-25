# L3 · 控制流、修饰符、错误处理

> 本节课目标：掌握 Solidity 里写逻辑分支、循环、权限控制和优雅报错的全套能力。

---

## 🎯 课程目标

学完本节课，学员可以：

1. 用 `if / else / 三元运算符` 写条件分支；
2. 用 `for / while` 写循环，并理解**链上循环的 gas 风险**；
3. 区分 `require` / `revert` / `assert` 三种错误处理方式；
4. 定义和使用 **Custom Errors**（自定义错误）省 gas；
5. 编写 **modifier** 做权限控制和状态守卫；
6. 把多个 modifier 叠加到一个函数上。

---

## 🗂️ 本课文件夹结构

```
lessons/L3/
├── README.md              ← 课程大纲（你正在看的）
├── ControlFlow.sol        ← 主合约，所有知识点都写在代码注释里
├── ControlFlow.t.sol      ← 测试，12 个用例覆盖核心概念
└── ControlFlow.s.sol      ← 部署脚本
```

---

## 📚 知识点地图

```
L3 · 控制流 & 错误处理
├── 条件分支
│   ├── if / else if / else
│   └── 三元运算符  condition ? a : b
├── 循环
│   ├── for 循环
│   ├── while 循环
│   ├── break / continue
│   └── ⚠️ unbounded loop 攻击面
├── 错误处理
│   ├── require(condition, "msg")  —— 输入校验
│   ├── revert CustomError()       —— 省 gas
│   └── assert(condition)          —— 内部不变量
├── 自定义错误（Custom Errors）
│   ├── 定义：error NotOwner(address, address)
│   └── 使用：revert NotOwner(...)
└── modifier 修饰符
    ├── 基本用法：onlyOwner / whenNotPaused
    ├── _; 的含义（函数体占位符）
    └── 多 modifier 叠加执行顺序
```

---

## ⏱️ 课堂节奏（2 小时）

| 阶段 | 时长 | 内容 |
|---|---|---|
| ① 复习 L2 + 引入"合约需要安全边界" | 10 min | 为什么需要 require / modifier？ |
| ② 逐段讲 ControlFlow.sol | 50 min | 8 个知识点 + 实战注释 |
| ③ 跑测试 + 讲解 expectRevert | 30 min | `FOUNDRY_PROFILE=l3 forge test -vv` |
| ④ modifier 组合演练 | 20 min | 让学员自己写一个 modifier |
| ⑤ Q&A + 课后作业 | 10 min | |

---

## 🚀 跑通命令（在工程根目录）

```shell
# 编译
FOUNDRY_PROFILE=l3 forge build

# 测试
FOUNDRY_PROFILE=l3 forge test -vv

# 部署到本地链（先开 anvil）
FOUNDRY_PROFILE=l3 forge script ControlFlow.s.sol:ControlFlowScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

---

## 🧠 速查表：错误处理对比

| 方式 | 用途 | Gas 行为 | 推荐场景 |
|---|---|---|---|
| `require(cond, "msg")` | 输入/前置条件校验 | 退还剩余 gas，附带字符串 | 简单校验、可读性优先 |
| `revert CustomError()` | 精细错误处理 | 退还剩余 gas，只占 4 字节 | 省 gas、前端需要解析错误 |
| `assert(cond)` | 内部逻辑不变量 | 退还剩余 gas（0.8+） | 绝不应该发生的错误 |

---

## 🧠 速查表：modifier 执行顺序

### `_;` 是什么？

`_;` 是 modifier 里的**占位符**，代表"被修饰的函数体"。`_;` **前面**的代码是前置检查，`_;` **后面**的代码是后置逻辑。

```solidity
modifier myMod() {
    // ← 这里是"前"（_; 之前的代码）
    doCheck();
    _;          // ← 函数体在这里执行
    // ← 这里是"后"（_; 之后的代码）
    doCleanup();
}
```

### 多个 modifier 嵌套 = 洋葱模型

```solidity
function foo() external modA modB modC {
    // 函数体
}
```

实际执行展开后像嵌套的洋葱：

```
modA 的 _; 前面代码
    modB 的 _; 前面代码
        modC 的 _; 前面代码
            函数体
        modC 的 _; 后面代码
    modB 的 _; 后面代码
modA 的 _; 后面代码
```

执行顺序：**进去从外到内（A→B→C→函数体），出来从内到外（C→B→A）**

### 具体示例

```solidity
modifier logA() {
    console.log("进入 A");  // 前
    _;
    console.log("离开 A");  // 后
}
modifier logB() {
    console.log("进入 B");  // 前
    _;
    console.log("离开 B");  // 后
}
function foo() external logA logB {
    console.log("函数体");
}
// 输出：进入A → 进入B → 函数体 → 离开B → 离开A
```

### 实际中的情况

90% 的 modifier 只有前置检查，`_;` 后面不写东西：

```solidity
modifier onlyOwner() {
    require(msg.sender == owner);  // 只有前置检查
    _;                              // 通过了就执行函数体，后面没代码
}
```

所以日常遇到的多 modifier 叠加，只关心"前前前→函数体"的顺序就行。

---

## 📝 课后作业

1. 给 `ControlFlow.sol` 添加一个 `removeFromWhitelist(address)` 函数，只有 owner 能调。写测试验证。
2. 写一个新的 modifier `onlyWhenCounterBelow(uint256 limit)`，当 counter >= limit 时 revert。把它加到 `increment()` 上，写测试验证上限。
3. 把 `addScore` 里的 `require("score must be <= 100")` 换成 custom error，跑 `forge test --gas-report` 对比两种写法的 gas 差异。
4. 思考题：如果 `scores` 数组可以被任何人无限 push，`totalScore()` 会有什么风险？

---

## 🧠 一句话总结

> **modifier 是合约的"保安"，require/revert 是合约的"刹车"**；写合约先想清楚"谁能调、什么时候能调、出错怎么办"，再写业务逻辑。
