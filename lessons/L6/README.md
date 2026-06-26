# L6 · ETH 转账与安全

> 本节课目标：理解 Web3 安全第一课 —— 重入攻击与防御，掌握 CEI 模式、重入锁、Pull 模式、DoS 防御。

---

## 🎯 课程目标

学完本节课，学员可以：

1. 解释**重入攻击（Reentrancy）**的原理和危害；
2. 掌握 **CEI 模式**（Checks-Effects-Interactions）；
3. 实现 **nonReentrant 重入锁**；
4. 区分 **Pull 模式**与 **Push 模式**；
5. 检查 `call` 返回值；
6. 识别并防御 **DoS（拒绝服务）攻击**；
7. 理解 `unchecked` 的使用场景；
8. 应用最小权限原则（onlyOwner + nonReentrant + CEI）。

---

## 🗂️ 本课文件夹结构

```
lessons/L6/
├── README.md                  ← 课程大纲（你正在看的）
├── ETHTransferSecurity.sol    ← 主合约：漏洞合约 + 安全合约 + 攻击者合约
├── ETHTransferSecurity.t.sol  ← 测试：15 个用例 + 模糊测试
└── ETHTransferSecurity.s.sol  ← 部署脚本
```

---

## 📚 知识点地图

```
L6 · ETH 转账与安全
├── 重入攻击
│   ├── 先转账后更新余额的漏洞
│   └── 黑客合约的 receive() 递归回调
├── CEI 模式
│   ├── Checks：先做条件检查
│   ├── Effects：立即更新状态
│   └── Interactions：最后才外部调用
├── 重入锁 nonReentrant
│   ├── _status：_NOT_ENTERED / _ENTERED
│   ├── OpenZeppelin 标准实现
│   └── 用 uint256 不用 bool（省 gas）
├── Pull vs Push
│   ├── Push：合约主动发钱（危险）
│   └── Pull：用户自己来取（推荐）
├── call 返回值检查
│   ├── (bool success, ) = addr.call{value: amount}("")
│   └── 必须检查 success
├── DoS 攻击
│   ├── 批量 push 时一人 revert 全失败
│   └── 防御：pull 模式 + 不要用 transfer
├── 整数溢出
│   ├── Solidity 0.8+ 自动检查
│   └── unchecked {} 省 gas
└── 最小权限原则
    ├── onlyOwner 危险操作
    └── 用户只能操作自己的资金
```

---

## ⏱️ 课堂节奏（2 小时）

| 阶段 | 时长 | 内容 |
|---|---|---|
| ① 复习 L5 + 引入"合约收钱后如何安全发钱" | 10 min | 为什么转账会有安全问题？ |
| ② 逐段讲 ETHTransferSecurity.sol | 50 min | 漏洞合约 vs 安全合约对比 |
| ③ 跑测试 + 讲解重入攻击过程 | 30 min | `FOUNDRY_PROFILE=l6 forge test -vv` |
| ④ 动手练：给 VulnerableBank 加 nonReentrant | 15 min | 看是否还需要 CEI |
| ⑤ Q&A + 课后作业 | 15 min | |

---

## 🚀 跑通命令（在工程根目录）

```shell
# 编译
FOUNDRY_PROFILE=l6 forge build

# 测试
FOUNDRY_PROFILE=l6 forge test -vv

# 部署到本地链（先开 anvil）
FOUNDRY_PROFILE=l6 forge script ETHTransferSecurity.s.sol:ETHTransferSecurityScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

---

## 🧠 速查表：重入攻击防御

| 防御手段 | 核心思想 | 代码示例 |
|---|---|---|
| **CEI 模式** | 先更新状态，再转账 | `balances -= amount;` 然后 `call` |
| **重入锁** | 标记函数执行中，禁止递归 | `modifier nonReentrant` |
| **Pull 模式** | 用户自己取钱 | 记录余额，提供 `withdraw()` |
| **call 检查** | 转账失败要 revert | `if (!success) revert TransferFailed(...)` |

```solidity
function withdraw(uint256 amount) external nonReentrant {
    // Checks
    if (amount > balances[msg.sender]) revert InsufficientBalance(...);

    // Effects
    balances[msg.sender] -= amount;

    // Interactions
    (bool success, ) = payable(msg.sender).call{value: amount}("");
    if (!success) revert TransferFailed(msg.sender, amount);
}
```

---

## 🧠 速查表：Pull vs Push

| 模式 | 谁发起转账 | 优点 | 缺点 |
|---|---|---|---|
| **Push** | 合约 | 用户体验好 | 重入风险、DoS 风险 |
| **Pull** | 用户 | 安全、可扩展、无 DoS | 用户需要主动操作 |

> **DeFi 黄金法则：永远用 Pull，不要用 Push。**

---

## 🧠 速查表：三种转账方式（复习 L5 + 安全结论）

| 方式 | 语法 | 是否推荐 | 原因 |
|---|---|---|---|
| transfer | `to.transfer(amount)` | ❌ | 2300 gas 限制 |
| send | `to.send(amount)` | ❌ | 2300 gas 限制 + 要手动检查 |
| **call** | `to.call{value: amount}("")` | ✅ | 转发全部 gas + 必须检查返回值 |

---

## 🧠 速查表：DoS 防御

| 攻击场景 | 防御方法 |
|---|---|
| 批量 push 转账一人失败全失败 | 用 pull 模式 |
| 外部调用失败卡住关键功能 | 不依赖外部调用成功 |
| 接收方合约 fallback 故意 revert | 用 call + 检查返回值，或 pull |

---

## 📝 课后作业

1. **思考题**：如果只在 `VulnerableBank.withdrawVulnerable()` 上加 `nonReentrant`，不加 CEI，能防御重入攻击吗？为什么？
2. **实践题**：把 `VulnerableBank` 改成安全版本（CEI + nonReentrant），写一个测试验证它不再被偷。
3. **实践题**：写一个 `BatchPayout` 合约，对比 push 模式的 DoS 风险和 pull 模式的安全性。
4. **拓展题**：查一下 2016 年 The DAO 黑客事件，它是重入攻击的经典案例，损失了多少 ETH？

---

## 🧠 一句话总结

> **ETH 转账安全 = CEI 模式 + 重入锁 + Pull 模式 + call 检查返回值。永远先更新自己的账本，再给别人打钱。**
