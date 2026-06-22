# L1 · 区块链 & Solidity 入门 + Foundry 环境

> 本节课目标：让学员**亲手跑通**一个最简单的 Solidity 应用（Hello World），建立"我能写区块链代码"的成就感。

---

## 🎯 课程目标

学完本节课，学员可以：

1. 说出区块链 / 智能合约 / EVM / Gas 的最小心智模型；
2. 知道 Foundry 四件套（forge / cast / anvil / chisel）分别干什么；
3. **独立完成** 编译 → 测试 → 本地部署 → 命令行调用 全流程；
4. 看懂一个最简单的 Solidity 合约（HelloWorld）。

---

## 🗂️ 本课文件夹结构

```
lessons/L1/
├── README.md           ← 你正在看的讲义大纲
├── HelloWorld.sol      ← 主合约（详细讲义都写在代码注释里）
├── HelloWorld.t.sol    ← 测试合约（讲解如何写单元测试）
└── HelloWorld.s.sol    ← 部署脚本（讲解如何上链）
```

**所有详细讲义都直接写在 `.sol` 文件的注释里**，学员边读代码边学，逐行解释，不留盲点。

---

## ⏱️ 课堂节奏（2 小时）

| 阶段 | 时长 | 内容 |
|---|---|---|
| ① 区块链快速心智模型 | 20 min | 区块链 / 以太坊 / 合约 / EVM / Gas |
| ② Foundry 工具链介绍 | 15 min | forge / cast / anvil / chisel |
| ③ 现场敲 HelloWorld.sol | 30 min | 逐行讲注释里的内容 |
| ④ 现场跑测试 | 20 min | `forge build` + `forge test -vv` |
| ⑤ 现场部署 + cast 调用 | 30 min | `anvil` + `forge script` + `cast` |
| ⑥ Q&A + 课后作业 | 5 min | 布置作业 |

---

## 🚀 跑通命令（教学现场照抄）

> 本课所有命令在工程**根目录**执行。  
> 因为 L1 的代码放在 `lessons/L1/` 这个独立文件夹，所以需要加上 `FOUNDRY_PROFILE=l1` 来切换到 L1 教学 profile（已经在 [foundry.toml](../../foundry.toml) 里配置好）。

### 1. 编译

```shell
FOUNDRY_PROFILE=l1 forge build
```

### 2. 跑测试

```shell
FOUNDRY_PROFILE=l1 forge test -vv
```

### 3. 起本地链（新开一个终端）

```shell
anvil
```

记下 anvil 输出的 **Account #0** 私钥（默认是公开的本地测试私钥）：

```
0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### 4. 部署到本地链

```shell
FOUNDRY_PROFILE=l1 forge script HelloWorld.s.sol:HelloWorldScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

记下输出里的合约地址，例如 `0x5FbDB23...`。

### 5. 用 cast 调用合约

```shell
# 读：拿到 greet 信息（不花 gas）
cast call <合约地址> "greet()(string)" --rpc-url http://127.0.0.1:8545

# 写：修改问候语
cast send <合约地址> "setGreeting(string)" "Hi Solidity" \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 再读一次，应当变成 "Hi Solidity"
cast call <合约地址> "greet()(string)" --rpc-url http://127.0.0.1:8545
```

---

## 📝 课后作业

1. 把 `HelloWorld.sol` 里的默认问候语改成你自己的名字，例如 `"Hello, 张三"`。
2. 重新跑 `FOUNDRY_PROFILE=l1 forge test -vv`，确认测试还能通过（**会失败**，让学员体会"代码改了测试就要跟着改"的道理）。
3. 修复测试，使其通过。
4. 把修复后的合约部署到 anvil，并用 `cast call` 读出新的问候语。
5. 把上面 4 步的终端截图发到学习群。

---

## 🧠 一句话总结

> **写合约 → 写测试 → 编译 → 测试 → 起本地链 → 部署 → 命令行调用**，这就是 DApp 开发的最小闭环。
