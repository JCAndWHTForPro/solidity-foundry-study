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

## 🧠 速查表：数据位置 vs 可见性

| 你声明的变量 | 默认 / 必须的数据位置 |
|---|---|
| 合约里的状态变量 | 永远 `storage`（不用写） |
| 函数里的局部变量（引用类型） | 必须显式写 `memory` 或 `storage` |
| 函数参数（外部 external） | 建议 `calldata`（省 gas） |
| 函数参数（内部 internal/private） | 一般 `memory` |
| 函数返回值（引用类型） | 一般 `memory` |

---

## 📝 课后作业

1. 在 `TypesDemo.sol` 里再加一个 `mapping(address => uint256) public scores`，写一个 `addScore(address, uint256)` 函数。
2. 给它写测试：两个地址各自 `addScore`，互不影响。
3. 把 `setNumbers` 的参数从 `calldata` 改成 `memory`，跑一遍 `forge test --gas-report`，对比 gas 差异。
4. 把对比结果发到学习群（截图）。

---

## 🧠 一句话总结

> **值类型直接拷贝，引用类型必须告诉编译器"住在哪"**；选错数据位置不仅多花 gas，还可能改不到你以为改的那个变量。
