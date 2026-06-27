// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// L6 · ETH 转账与安全
//
// 💡 本文件承接 L5，深入讲解合约收发 ETH 的安全隐患与防御模式：
//    重入攻击、Checks-Effects-Interactions、pull 模式、重入锁、
//    拒绝服务、CEI 实战、安全取款等。
//
// Java 程序员注意：
//   - Solidity 转账失败不会自动抛异常（除了 transfer）
//   - 合约调用合约时，被调用方可以在你状态更新前回调你 → 重入攻击
//   - 这是 Web3 安全第一课，必须彻底理解
// ─────────────────────────────────────────────────────────────────────────────

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 1】重入攻击（Reentrancy）原理
//
//   场景：合约 A 向合约 B 转账 ETH，B 的 fallback/receive 又回调 A 的函数，
//        在 A 的状态变量还没更新时再次取款。
//
//   经典流程（以取款为例）：
//     1. 黑客合约调用 A.withdraw()
//     2. A 检查 balance[黑客] > 0 通过
//     3. A 用 call 给黑客转账
//     4. 黑客的 receive() 又调用 A.withdraw()
//     5. A 的检查又通过（因为步骤 5 还没执行）
//     6. 循环往复，直到 ETH 被掏空
//
//   💡 类比 Java：就像 Servlet 过滤器链里，doFilter() 还没走完你就提前
//     把响应发给客户端，客户端立刻又发一次请求，服务端状态还是旧的。
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 2】CEI 模式 —— Checks, Effects, Interactions
//
//   这是防御重入攻击的黄金法则：
//     1. Checks：先做所有条件检查（require / if）
//     2. Effects：立即更新状态变量
//     3. Interactions：最后才和外部合约交互（转账 / call）
//
//   只要 Effects 在 Interactions 之前完成，即使对方重入，检查也会失败。
//
//   ❌ 错误顺序：检查 → 转账 → 更新余额（容易被重入）
//   ✅ 正确顺序：检查 → 更新余额 → 转账（安全）
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 3】重入锁（Reentrancy Guard）
//
//   用布尔变量或枚举标记"是否正在执行关键函数"，防止递归调用。
//
//   OpenZeppelin 标准实现：
//
//     uint256 private _status;
//
//     💡 可见性(private/public/internal)后面还可以跟这些修饰符：
//       - constant  : 编译期确定，不占存储槽，必须在声明时赋值，不能修改
//       - immutable : 部署时确定（可在 constructor 中赋值），之后不能修改，不占存储槽
//       - (无修饰符) : 普通状态变量，存储在 storage 中，可以修改
//
//     对比：
//       uint256 private constant X = 1;      // 编译时写死，gas 最省
//       uint256 private immutable Y;         // 构造时赋值，gas 较省
//       uint256 private z;                   // 运行时可改，gas 最贵（SSTORE/SLOAD）
//
//     类比 Java：
//       constant  ≈ static final int X = 1;        (编译期常量)
//       immutable ≈ final int y; (构造器中赋值)      (运行期常量)
//       普通变量   ≈ private int z;                  (可变字段)
//     uint256 private constant _NOT_ENTERED = 1;

//     uint256 private constant _ENTERED = 2;
//
//     modifier nonReentrant() {
//         require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
//         _status = _ENTERED;
//         _;
//         _status = _NOT_ENTERED;
//     }
//
//   💡 用 uint256 不用 bool：因为 EVM 中将存储槽从 0 改为非 0 需要 20000 gas（冷写入），
//     而从非 0 改为非 0 只需 5000 gas（热写入）。使用 uint256 的 1 和 2（都是非零值）
//     切换状态，避免了 0↔1 的昂贵转换；而 bool 的 false(0)↔true(1) 每次都触发冷写入。
//     类比 Java：相当于用 int status=1/2 代替 boolean locked=false/true，底层执行效率更高。
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 4】Pull 模式 vs Push 模式
//
//   Push 模式：合约主动把钱转给用户
//     - 风险：如果对方是恶意合约，可能重入或拒绝收款
//     - 风险：批量转账时，一个地址失败导致全部失败
//
//   Pull 模式：用户自己来取钱
//     - 合约只记录"谁可以取多少"
//     - 用户主动调用 withdraw() 把钱取走
//     - 更安全、更可扩展
//
//   💡 类比 Java：Push 像公司主动给员工发工资；Pull 像员工自己去 ATM 取。
//     发工资时一人账户异常会导致全公司发不出工资；自己取就不会互相影响。
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 5】call 返回值必须检查
//
//   (bool success, ) = addr.call{value: amount}("");
//   if (!success) { revert ... }
//
//   如果不检查 success，对方即使收款失败，你的合约也认为转账成功，
//   继续执行后面的逻辑，造成状态不一致。
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 6】拒绝服务（DoS）攻击
//
//   场景 1：批量 push 转账时，某个接收方是恶意合约，故意让 fallback revert，
//          导致整个循环失败。
//
//   场景 2：合约依赖外部调用返回成功才继续，攻击者让外部调用永远失败，
//          卡住关键功能。
//
//   防御：
//     - 用 pull 模式代替 push 模式
//     - 不要用 transfer（2300 gas 可能让正常合约也 revert）
//     - 批量操作时不要让一个人的失败影响所有人
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 7】整数溢出与 underflow
//
//   Solidity 0.8.0 之前：uint256 减法下溢会变成 2^256-1，导致严重漏洞
//   Solidity 0.8.0 之后：编译器自动检查，溢出 / 下溢会 panic revert
//
//   但 unchecked 块里不会检查：
//     unchecked { balance -= amount; }
//
//   💡 何时用 unchecked？确定不会溢出、想省 gas 的核心计算。
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 8】最小权限原则与 Access Control
//
//   - 只有 owner 才能做危险操作（提取全部资金、暂停合约）
//   - 用户只能操作自己的资金
//   - 不要信任任何外部输入（地址、金额、calldata）
//
//   结合 L4 的 onlyOwner + 本课的 nonReentrant + CEI，
//   就是一个基础版安全合约的必备三件套。
// ═════════════════════════════════════════════════════════════════════════════


/// @title 一个容易被重入攻击的示例合约（仅用于教学演示漏洞）
contract VulnerableBank {
    mapping(address => uint256) public balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function deposit() external payable {
        // msg.value 不是当前账户拥有多少钱，而是本次调用时随交易附带发送的 ETH 数量。
        // 账户总余额是 address(msg.sender).balance，而 msg.value 只是这一次转入合约的金额。
        // 类比 Java：msg.value 相当于本次 HTTP 请求体里的"转账金额"字段，不是账户余额。
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /// ❌ 漏洞版本：先转账，后更新余额
    function withdrawVulnerable() external {
        // balances 中的钱是通过上面的 deposit() 函数存入的：
        // 用户调用 deposit() 并附带 ETH（msg.value），合约就把金额累加到 balances[msg.sender]
        uint256 amount = balances[msg.sender];
        require(amount > 0, "no balance");

        // 危险：外部 call 先执行，余额还没扣
        // 💡 在 Solidity 0.8.x 中，.call{value:} 对 address 和 address payable 都可用，
        //    所以 msg.sender 不加 payable 也能编译通过。
        //    但推荐加上 payable() 显式表达"向该地址发送 ETH"的意图（如 SecureBank 中那样）。
        //    只有 .transfer() 和 .send() 才强制要求 address payable 类型。
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "transfer failed");

        balances[msg.sender] = 0; // 更新太晚，重入已经发生
        emit Withdrawn(msg.sender, amount);
    }
}


/// @title 安全的银行合约：CEI + 重入锁 + Pull 模式
contract SecureBank {
    address public owner;

    // 重入锁状态
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    mapping(address => uint256) public balances;
    uint256 public totalDeposits;

    // ───── 事件 ─────
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event OwnerWithdrawn(uint256 amount);

    // ───── 自定义错误 ─────
    error ReentrantCall();
    error InsufficientBalance(uint256 requested, uint256 available);
    error TransferFailed(address recipient, uint256 amount);
    error NotOwner(address caller);
    error ZeroAmount();

    // ───── 重入锁 Modifier ─────
    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor() {
        owner = msg.sender;
        _status = _NOT_ENTERED;
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 2 + 4 实战】安全的存款与取款（CEI + Pull 模式）
    // ═════════════════════════════════════════════════════════════════════

    /// 存款：任何人都可以存
    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();

        // Effects：先更新状态
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    /// 取款：用户自己来取（Pull 模式），带重入锁
    function withdraw(uint256 amount) external nonReentrant {
        // Checks
        if (amount > balances[msg.sender]) {
            revert InsufficientBalance(amount, balances[msg.sender]);
        }

        // Effects：先扣余额
        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        // Interactions：最后才转账
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert TransferFailed(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, amount);
    }

    /// 一键取走全部余额
    function withdrawAll() external nonReentrant {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert InsufficientBalance(1, 0);

        // Effects
        balances[msg.sender] = 0;
        totalDeposits -= amount;

        // Interactions
        // 💡 这是 Solidity 的"解构赋值"（Destructuring Assignment）：
        //    .call() 返回两个值：(bool success, bytes memory returnData)
        //    写成 (bool success, ) 表示只接收第一个返回值，第二个用逗号占位丢弃
        //    类比 Java：相当于 Pair<Boolean, byte[]> result = call(...);
        //              boolean success = result.getFirst(); // 忽略 second
        //
        // 💡 {value: amount} 是"函数调用选项"（Function Call Options），
        //    用花括号附带在 .call 上，表示本次调用随附发送 amount 数量的 ETH
        //    类似于 HTTP 请求里附带 header/body 参数
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert TransferFailed(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, amount);
    }

    /// 专门用于测试重入锁：进入后回调 msg.sender，
    /// 如果 msg.sender 在回调里再次调用 protectedAction，则会触发 ReentrantCall
    function protectedAction() external nonReentrant {
        ILockCallback(msg.sender).lockCallback();
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 6 实战】避免 DoS：owner 提取全部余额
    // ═════════════════════════════════════════════════════════════════════

    /// owner 提取合约剩余全部 ETH（不是用户存款，是手续费等）
    function ownerWithdraw() external onlyOwner nonReentrant {
        // Checks
        // address(this).balance 是合约持有的全部 ETH，包括用户存款 + 手续费/直接转入的 ETH
        // totalDeposits 追踪了所有用户通过 deposit() 存入的资金
        // 两者之差就是"非用户存款"的部分（手续费、直接转入等），owner 只能提取这部分
        // 💡 receive() 虽然会收 ETH 并 emit 事件，但没有更新 totalDeposits，
        //    所以通过 receive() 直接转入的 ETH 也属于"手续费"范畴
        uint256 amount = address(this).balance - totalDeposits;
        if (amount == 0) revert ZeroAmount();

        // Effects：先发出事件（本函数无需修改其他状态变量，但 emit 也属于 effect）
        emit OwnerWithdrawn(amount);

        // Interactions：最后才进行外部调用
        (bool success, ) = payable(owner).call{value: amount}("");
        if (!success) {
            revert TransferFailed(owner, amount);
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 7 实战】unchecked 省 gas
    // ═════════════════════════════════════════════════════════════════════

    /// 批量加余额（已知 total 不会溢出时使用 unchecked）
    function batchDepositFor(address[] calldata users, uint256[] calldata amounts) external payable onlyOwner {
        require(users.length == amounts.length, "length mismatch");

        uint256 total;
        for (uint256 i = 0; i < users.length; i++) {
            total += amounts[i];
            balances[users[i]] += amounts[i];
        }

        if (total != msg.value) revert ZeroAmount(); // 复用 ZeroAmount 表示金额不匹配

        // 已知 total <= msg.value，totalDeposits += total 也不会溢出
        unchecked {
            totalDeposits += total;
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // 查询函数
    // ═════════════════════════════════════════════════════════════════════

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // 接收纯 ETH
    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }
}


/// @title 回调接口：供 protectedAction 调用
interface ILockCallback {
    function lockCallback() external;
}


/// @title 模拟黑客合约：用重入攻击 VulnerableBank
contract ReentrancyAttacker {
    VulnerableBank public target;
    uint256 public attackCount;
    uint256 public constant MAX_ATTACKS = 5;

    constructor(address _target) {
        target = VulnerableBank(_target);
    }

    // 开始攻击
    function attack() external payable {
        require(msg.value >= 1 ether, "need 1 ether");
        target.deposit{value: 1 ether}();
        target.withdrawVulnerable();
    }

    // 每次收到 ETH 就再次调用取款，直到达到最大次数
    receive() external payable {
        if (attackCount < MAX_ATTACKS) {
            attackCount++;
            target.withdrawVulnerable();
        }
    }

    function getStolenAmount() external view returns (uint256) {
        return address(this).balance;
    }
}


/// @title 模拟黑客合约：尝试重入 SecureBank（会失败）
contract FailedAttacker {
    SecureBank public target;
    uint256 public attackCount;

    constructor(address payable _target) {
        target = SecureBank(_target);
    }

    function attack() external payable {
        require(msg.value >= 1 ether, "need 1 ether");
        target.deposit{value: 1 ether}();
        target.withdraw(0.5 ether); // 只取一半，剩下的在 receive 里重入
    }

    receive() external payable {
        attackCount++;
        // 第一次 withdraw 已经先扣了余额，
        // 再次重入 withdraw 时余额不足，会因 TransferFailed 而 revert
        target.withdraw(0.5 ether);
    }
}


/// @title 专门测试 nonReentrant 重入锁会触发 ReentrantCall
contract LockTester is ILockCallback {
    SecureBank public target;

    constructor(address payable _target) {
        target = SecureBank(_target);
    }

    function attack() external payable {
        require(msg.value >= 1 ether, "need 1 ether");
        target.deposit{value: 1 ether}();
        // protectedAction 进入后，会回调本合约的 lockCallback
        target.protectedAction();
    }

    function lockCallback() external override {
        // 此时 protectedAction 还没执行完，_status 是 _ENTERED
        // 再次调用 protectedAction 会直接触发 ReentrantCall
        target.protectedAction();
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 🎓 本文件涵盖的 8 个知识点：
//   1. 重入攻击原理（先转账后更新余额的漏洞）
//   2. CEI 模式（Checks → Effects → Interactions）
//   3. 重入锁 nonReentrant 实现
//   4. Pull 模式 vs Push 模式
//   5. call 返回值必须检查
//   6. 拒绝服务（DoS）攻击与防御
//   7. 整数溢出与 unchecked
//   8. 最小权限原则 / Access Control
//
// 下一步：去看 ETHTransferSecurity.t.sol，里面会演示真实攻击和防御测试。
// ─────────────────────────────────────────────────────────────────────────────
