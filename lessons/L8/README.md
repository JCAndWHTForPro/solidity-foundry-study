# L8 · ERC20 代币实战

> 本节课目标：从零手写一个完整的 ERC20 代币合约，理解代币标准的每一行代码，掌握 approve/transferFrom 授权机制。

---

## 🎯 课程目标

学完本节课，学员可以：

1. 解释 **ERC20 标准**的 6 个函数 + 2 个事件的作用；
2. 理解 **approve + transferFrom** 的授权代扣机制；
3. 区分 **decimals** 与精度的关系；
4. 实现完整的 **mint（铸造）和 burn（销毁）**；
5. 理解 **无限授权**（type(uint256).max）的利弊；
6. 掌握 ERC20 在 **DeFi 中的实际应用**流程；
7. 了解 ERC20 常见**安全问题**（竞态攻击、假代币）；
8. 编写一个简单的 **ICO 合约**实战。

---

## 🗂️ 本课文件夹结构

```
lessons/L8/
├── README.md             ← 课程大纲（你正在看的）
├── ERC20Token.sol        ← 主合约：IERC20 接口 + 完整实现 + ICO 合约
├── ERC20Token.t.sol      ← 测试：34 个单元测试 + 2 个模糊测试
└── ERC20Token.s.sol      ← 部署脚本
```

---

## 📚 知识点地图

```
L8 · ERC20 代币实战
├── ERC20 是什么
│   ├── 接口标准（钱包/DEX 依赖）
│   ├── 代币 ≠ ETH（只是 mapping 里的数字）
│   └── 为什么需要统一标准
├── 6 个核心函数
│   ├── totalSupply() — 总供应量
│   ├── balanceOf(address) — 余额查询
│   ├── transfer(to, amount) — 直接转账
│   ├── approve(spender, amount) — 授权额度
│   ├── allowance(owner, spender) — 查询授权
│   └── transferFrom(from, to, amount) — 代扣
├── approve + transferFrom 机制
│   ├── 为什么 DEX 不能直接 transfer
│   ├── 用户 approve → 合约 transferFrom
│   ├── 授权是"覆盖"不是"增加"
│   └── 无限授权 type(uint256).max
├── decimals 精度
│   ├── EVM 只有整数，没有小数
│   ├── decimals=18 → 1e18 = 1个代币
│   └── USDT/USDC 用 decimals=6
├── mint 与 burn
│   ├── mint：from = address(0)
│   ├── burn：to = address(0)
│   └── cap：最大供应量限制
├── DeFi 应用流程
│   ├── DEX：approve → swap
│   ├── 借贷：approve → deposit
│   ├── 质押：approve → stake
│   └── ICO：ETH → mint token
├── 安全问题
│   ├── approve 竞态攻击
│   ├── 假代币攻击
│   ├── 无限授权风险
│   └── transfer 到合约 = 代币丢失
└── 实现模式
    ├── 手写（本课教学）
    └── OpenZeppelin 继承（生产推荐）
```

---

## ⏱️ 课堂节奏（2.5 小时）

| 阶段 | 时长 | 内容 |
|---|---|---|
| ① 引入"什么是代币" | 15 min | 代币 vs ETH、为什么需要 ERC20 标准 |
| ② 逐段讲 ERC20Token.sol | 60 min | 8 个知识点 + 完整实现 |
| ③ 重点讲 approve/transferFrom | 20 min | 画流程图、对比银行代扣 |
| ④ 跑测试 + 讲解 ICO 合约 | 30 min | `FOUNDRY_PROFILE=l8 forge test -vv` |
| ⑤ 动手练：添加 Pausable 功能 | 15 min | modifier + 暂停时禁止 transfer |
| ⑥ Q&A + 课后作业 | 10 min | |

---

## 🚀 跑通命令（在工程根目录）

```shell
# 编译
FOUNDRY_PROFILE=l8 forge build

# 测试
FOUNDRY_PROFILE=l8 forge test -vv

# 部署到本地链（先开 anvil）
FOUNDRY_PROFILE=l8 forge script ERC20Token.s.sol:ERC20TokenScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

---

## 🧠 速查表：ERC20 核心函数

| 函数 | 谁调用 | 作用 | 返回值 |
|---|---|---|---|
| `totalSupply()` | 任何人 | 查询代币总量 | uint256 |
| `balanceOf(addr)` | 任何人 | 查询某地址余额 | uint256 |
| `transfer(to, amount)` | 持有者 | 直接转账 | bool |
| `approve(spender, amount)` | 持有者 | 授权代扣额度 | bool |
| `allowance(owner, spender)` | 任何人 | 查询授权额度 | uint256 |
| `transferFrom(from, to, amount)` | 被授权者 | 代扣转账 | bool |

---

## 🧠 速查表：approve + transferFrom 流程

```
用户（Alice）                DEX合约（Uniswap）              代币合约
    │                              │                            │
    │── 1. approve(DEX, 100) ──────────────────────────────────►│  ← 记录 allowance
    │                              │                            │
    │── 2. 调用 DEX.swap() ───────►│                            │
    │                              │── 3. transferFrom(Alice,   │
    │                              │       DEX, 100) ──────────►│  ← 检查 allowance，扣款
    │                              │                            │
    │                              │◄── 4. 转账成功 ────────────│
    │◄── 5. swap 完成 ────────────│                            │
```

---

## 🧠 速查表：decimals 精度

| 代币 | decimals | 合约里 1 个代币的值 | 说明 |
|---|---|---|---|
| 大多数代币 | 18 | `1e18` | 与 ETH 精度一致 |
| USDT/USDC | 6 | `1e6` | 美元稳定币 |
| WBTC | 8 | `1e8` | 比特币精度 |

```solidity
// "转 100 个代币" 在合约里写成：
token.transfer(to, 100 * 10 ** token.decimals());
// 如果 decimals = 18 → 转 100e18 最小单位
```

---

## 🧠 速查表：ERC20 事件

| 事件 | 触发时机 | from | to |
|---|---|---|---|
| `Transfer(from, to, value)` | transfer / transferFrom | 发送者 | 接收者 |
| `Transfer(0x0, to, value)` | mint | address(0) | 接收者 |
| `Transfer(from, 0x0, value)` | burn | 持有者 | address(0) |
| `Approval(owner, spender, value)` | approve | 持有者 | 被授权者 |

---

## 🧠 速查表：常见安全问题

| 问题 | 描述 | 防御 |
|---|---|---|
| approve 竞态 | 两次 approve 之间被抢跑 | 先 approve(0) 再 approve(n) |
| 无限授权风险 | DApp 被黑后掏空用户代币 | 只授权需要的额度 |
| 假代币 | 部署同名代币冒充正版 | 验证合约地址 |
| 转入黑洞 | transfer 到不处理 ERC20 的合约 | 使用 safeTransfer（OpenZeppelin） |

---

## 📝 课后作业

1. **实践题**：给 MyERC20 添加 `pause()` / `unpause()` 功能，暂停时禁止 transfer 和 transferFrom。写测试验证。
2. **实践题**：实现一个 `Airdrop` 合约：owner 调用 `batchAirdrop(address[], uint256[])` 批量给多个地址发代币。
3. **思考题**：为什么 Uniswap 要求先 approve 再 swap？能不能直接把代币 transfer 给 Uniswap 合约？
4. **拓展题**：用 `cast` 命令行在 anvil 上完成完整流程：部署代币 → approve → transferFrom，截图记录每一步的状态变化。

---

## 🧠 一句话总结

> **ERC20 = 代币世界的通用语言。transfer 是"我转给你"，approve+transferFrom 是"我授权你从我这拿"。所有 DeFi 交互的第一步都是 approve——理解了这个，就理解了 DeFi 的入口。**
