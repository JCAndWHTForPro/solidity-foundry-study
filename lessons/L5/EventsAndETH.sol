// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// L5 · 事件（Events）与 ETH 收发
//
// 💡 本文件演示 Solidity 中事件系统和以太币收发的全部核心知识：
//    事件定义与触发、indexed 参数、receive/fallback、payable 函数、
//    ETH 余额查询、msg.value、合约向外转账。
//
// Java 程序员注意：
//   - 事件 ≈ 日志系统（但写在链上，前端可以实时订阅）
//   - payable ≈ 标注"这个方法可以接收钱"
//   - receive/fallback ≈ 合约的"默认方法"（没调用任何函数时触发）
// ─────────────────────────────────────────────────────────────────────────────


// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 1】事件（Event）定义与触发
//
//   • 关键字：event 定义，emit 触发
//   • 事件数据存储在「交易日志（Transaction Log）」中，不占 storage
//   • 链下工具（前端 / The Graph / 监控系统）可以监听事件
//   • 比写 storage 便宜得多（约 375 gas/字节 vs 20000 gas/slot）
//
//   💡 类比 Java：类似于发布一条日志 logger.info("Transfer happened")，
//     但这条日志永久写在区块链上，任何人都能查到。
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 2】indexed 参数
//
//   • 事件参数加 indexed → 变成「可搜索的索引」
//   • 最多 3 个 indexed 参数（EVM topic 槽位限制）
//   • 非 indexed 参数放在 data 区域（不能直接搜索，但能存更多数据）
//
//   实际用途：
//     - 前端只想看"Alice 的转账记录" → 按 indexed from/to 过滤
//     - 不需要搜索的大数据（如备注）→ 放非 indexed
//
//   💡 类比：indexed ≈ 数据库索引字段（WHERE from = 0xAlice）
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 3】payable 函数
//
//   • 函数加 payable → 允许调用时附带 ETH（msg.value > 0）
//   • 不加 payable 的函数，如果调用时附带 ETH → 自动 revert
//   • 合约收到的 ETH 存在合约地址的余额里：address(this).balance
//
//   💡 类比 Java：类似于方法参数里多了一个隐含的 money 参数，
//     只有标注 @Payable 的方法才能接收这个参数。
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 4】receive() 和 fallback()
//
//   • receive() external payable：
//     - 当合约收到纯 ETH 转账（没有 calldata）时自动触发
//     - 不能有参数，不能有返回值
//     - 典型用途：接收 ETH + 记录日志
//
//   • fallback() external payable：
//     - 当调用了合约上不存在的函数时触发
//     - 或者发送 ETH 但没有 receive() 时也会触发
//     - 可以有 calldata（bytes calldata）
//
//   两者的优先级：
//     msg.data 为空 → 调用 receive()（如果有）
//     msg.data 不为空 / 函数不存在 → 调用 fallback()
//     都没有 → 交易 revert
//
//   💡 类比 Java：receive ≈ 默认构造方法，fallback ≈ Method.invoke 找不到方法时的兜底
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 5】msg.value 和 address(this).balance
//
//   • msg.value：本次调用附带的 ETH 数量（单位：wei）
//   • address(this).balance：当前合约持有的 ETH 总余额
//   • 1 ether = 10^18 wei
//   • 1 gwei  = 10^9 wei
//
//   ⚠️ 重要：msg.value 在函数执行前就已经到账了！
//     即使函数 revert，ETH 也会被退回（原子性）。
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 6】合约向外转账的三种方式
//
//   1. addr.transfer(amount)
//      - 失败自动 revert
//      - 固定 2300 gas（只够触发事件，不够执行复杂逻辑）
//      - ⚠️ 不推荐（2300 gas 限制可能导致接收方 revert）
//
//   2. addr.send(amount) → returns (bool)
//      - 失败返回 false（不会自动 revert）
//      - 同样 2300 gas 限制
//      - ⚠️ 不推荐（必须手动检查返回值）
//
//   3. addr.call{value: amount}("") → returns (bool, bytes)
//      - 推荐方式！
//      - 不限制 gas（可转发所有剩余 gas）
//      - 必须检查返回值
//      - ⚠️ 注意重入风险（L6 会讲安全防护）
//
//   💡 当前最佳实践：用 call + 检查返回值 + 重入锁
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 7】ETH 单位
//
//   Solidity 内置单位关键字：
//     1 wei      = 1（最小单位）
//     1 gwei     = 1e9 wei
//     1 ether    = 1e18 wei
//
//   这些是编译时常量，可以直接用于比较和运算：
//     require(msg.value >= 0.01 ether, "too little");
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 8】事件在实际 DeFi 中的作用
//
//   • Uniswap：每次 swap 触发 Swap 事件 → 前端实时显示价格
//   • ERC20：每次转账触发 Transfer 事件 → 钱包显示交易历史
//   • OpenSea：监听 Transfer 事件 → 更新 NFT 持有者
//   • The Graph：索引所有事件 → 提供 GraphQL API
//
//   事件是链上合约与链下世界的桥梁。
// ═════════════════════════════════════════════════════════════════════════════


contract EventsAndETH {
    // ───── 状态变量 ─────
    address public owner;
    uint256 public totalDeposits;
    mapping(address => uint256) public balances;

    // ───── 事件定义 ─────

    /// 存款事件：indexed 让前端可以按存款人过滤
    event Deposited(address indexed depositor, uint256 amount, uint256 timestamp);

    /// 取款事件
    event Withdrawn(address indexed recipient, uint256 amount);

    /// 收到纯 ETH 转账（通过 receive）
    event Received(address indexed sender, uint256 amount);

    /// 收到不明调用（通过 fallback）
    event FallbackCalled(address indexed sender, uint256 amount, bytes data);

    /// 转账失败事件
    event TransferFailed(address indexed recipient, uint256 amount);

    // ───── 自定义错误 ─────
    error NotOwner(address caller);
    error InsufficientBalance(uint256 requested, uint256 available);
    error DepositTooSmall(uint256 sent, uint256 minimum);
    error WithdrawFailed(address recipient, uint256 amount);
    error ZeroAddress();

    // ───── Modifier ─────
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    // ───── 构造函数 ─────
    constructor() {
        owner = msg.sender;
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 3 实战】payable 函数：存款
    // ═════════════════════════════════════════════════════════════════════

    /// 存款：必须附带 ETH，最少 0.001 ether
    function deposit() external payable {
        if (msg.value < 0.001 ether) {
            revert DepositTooSmall(msg.value, 0.001 ether);
        }

        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;

        // 【知识点 1 实战】触发事件
        emit Deposited(msg.sender, msg.value, block.timestamp);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 6 实战】合约向外转账（推荐方式：call）
    // ═════════════════════════════════════════════════════════════════════

    /// 取款：从合约提取自己存入的 ETH
    function withdraw(uint256 amount) external {
        if (amount > balances[msg.sender]) {
            revert InsufficientBalance(amount, balances[msg.sender]);
        }

        // 先更新状态（Checks-Effects-Interactions 模式）
        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        // 再转账（用 call，推荐方式）
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            // 转账失败，恢复状态
            balances[msg.sender] += amount;
            totalDeposits += amount;
            revert WithdrawFailed(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, amount);
    }

    /// Owner 提取合约所有余额
    function withdrawAll() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        if (contractBalance == 0) {
            revert InsufficientBalance(1, 0);
        }

        (bool success, ) = payable(owner).call{value: contractBalance}("");
        if (!success) {
            revert WithdrawFailed(owner, contractBalance);
        }

        emit Withdrawn(owner, contractBalance);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 4 实战】receive 和 fallback
    // ═════════════════════════════════════════════════════════════════════

    /// 接收纯 ETH 转账（无 calldata）
    receive() external payable {
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit Received(msg.sender, msg.value);
    }

    /// 兜底函数：调用了不存在的函数，或有 calldata 的 ETH 转账
    fallback() external payable {
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit FallbackCalled(msg.sender, msg.value, msg.data);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 5 实战】查询余额
    // ═════════════════════════════════════════════════════════════════════

    /// 查询合约当前持有的 ETH 总量
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// 查询某用户的存款余额
    function getBalance(address user) external view returns (uint256) {
        if (user == address(0)) revert ZeroAddress();
        return balances[user];
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 6 补充】三种转账方式演示（仅供学习对比）
    // ═════════════════════════════════════════════════════════════════════

    /// 方式 1：transfer（不推荐，2300 gas 限制）
    function sendViaTransfer(address payable to, uint256 amount) external onlyOwner {
        to.transfer(amount);
        emit Withdrawn(to, amount);
    }

    /// 方式 2：send（不推荐，必须检查返回值）
    function sendViaSend(address payable to, uint256 amount) external onlyOwner {
        bool success = to.send(amount);
        if (!success) {
            emit TransferFailed(to, amount);
            revert WithdrawFailed(to, amount);
        }
        emit Withdrawn(to, amount);
    }

    /// 方式 3：call（推荐！）
    function sendViaCall(address payable to, uint256 amount) external onlyOwner {
        (bool success, ) = to.call{value: amount}("");
        if (!success) {
            revert WithdrawFailed(to, amount);
        }
        emit Withdrawn(to, amount);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 7 实战】ETH 单位使用
    // ═════════════════════════════════════════════════════════════════════

    /// 演示 ETH 单位：返回各单位的 wei 值
    function ethUnits() external pure returns (uint256 oneWei, uint256 oneGwei, uint256 oneEther) {
        oneWei = 1 wei;
        oneGwei = 1 gwei;
        oneEther = 1 ether;
    }

    /// 检查存款是否达到 VIP 门槛（0.1 ether）
    function isVIP(address user) external view returns (bool) {
        return balances[user] >= 0.1 ether;
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 🎓 本文件涵盖的 8 个知识点：
//   1. 事件定义与触发（event + emit）
//   2. indexed 参数（可搜索索引，最多 3 个）
//   3. payable 函数（允许接收 ETH）
//   4. receive() / fallback()（纯转账 / 兜底调用）
//   5. msg.value / address(this).balance（ETH 余额查询）
//   6. 三种转账方式对比（transfer / send / call）
//   7. ETH 单位（wei / gwei / ether）
//   8. 事件在 DeFi 中的实际作用
//
// 下一步：去看 EventsAndETH.t.sol，从测试里验证这些知识点。
// ─────────────────────────────────────────────────────────────────────────────
