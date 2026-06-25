// SPDX-License-Identifier: MIT
// ─────────────────────────────────────────────────────────────────────────────
// 【L3 · 主合约】ControlFlow.sol —— 控制流、修饰符、错误处理一站式演示
//
// 📚 本文件就是讲义本身。每个"知识点"都用注释包起来，逐段念给学员听。
//    L3 要解决的核心问题："合约里怎么写 if/else、循环，怎么做权限控制，
//    出错了怎么优雅地 revert？"
// ─────────────────────────────────────────────────────────────────────────────

pragma solidity ^0.8.13;


/// @title ControlFlow - 演示 Solidity 控制流、修饰符与错误处理
/// @notice 一份"看完就能掌握 if/for/modifier/require/custom error"的合约
contract ControlFlow {

    // ═════════════════════════════════════════════════════════════════════
    // 状态变量（供后续知识点使用）
    // ═════════════════════════════════════════════════════════════════════
    address public owner;
    bool public paused;
    uint256 public counter;
    mapping(address => bool) public whitelist;
    uint256[] public scores;


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 1】自定义错误（Custom Errors）
    //
    //   • Solidity 0.8.4+ 引入，比 require("字符串") 省 gas；
    //   • 用法：先在合约顶部定义 error，再在函数里 revert ErrorName()；
    //   • 可以带参数，方便前端/测试捕获具体信息。
    //
    //   ⚠️ 为什么比字符串省 gas？
    //     require("msg") 会把整个字符串存入 returndata（按字节计费），
    //     而 custom error 只占 4 字节选择器 + 参数编码，更紧凑。
    // ═════════════════════════════════════════════════════════════════════
    error NotOwner(address caller, address requiredOwner);
    error ContractPaused();
    error NotWhitelisted(address caller);
    error InvalidScore(uint256 score, string reason);
    error NoScores();
    error ExceesLimit(uint256 limit);
    error NotExceed(string msg);


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 2】事件（配合后面的功能使用）
    // ═════════════════════════════════════════════════════════════════════
    event CounterIncremented(address indexed by, uint256 newValue);
    event ScoreAdded(uint256 score);
    event Paused(address by);
    event Unpaused(address by);


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 3】modifier 修饰符
    //
    //   • modifier 是给函数加"前置/后置检查"的语法糖；
    //   • 一个函数可以叠加多个 modifier，从左到右依次执行；
    //   • _; 代表"被修饰的函数体"，写在 _; 前面的代码是前置检查，
    //     写在 _; 后面的代码是后置检查（不常用但合法）。
    //
    //   典型用途：
    //     1) 权限控制（onlyOwner）
    //     2) 状态检查（whenNotPaused）
    //     3) 重入锁（nonReentrant，后面课程会讲）
    //
    //   💡 modifier 里也可以用 require / revert，检查不通过直接回滚。
    // ═════════════════════════════════════════════════════════════════════

    /// 只有合约部署者才能调用
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender, owner);
        }
        _;   // ← 检查通过后，才执行被修饰的函数体
    }

    /// 合约没有被暂停时才能调用
    modifier whenNotPaused() {
        if (paused) {
            revert ContractPaused();
        }
        _; // `_` 是 modifier 的占位符，代表"被修饰函数的函数体"，检查通过后会从这里继续执行函数逻辑
    }

    /// 只有白名单用户才能调用
    modifier onlyWhitelisted() {
        if (!whitelist[msg.sender]) {
            revert NotWhitelisted(msg.sender);
        }
        _;
    }

    modifier onlyWhenCounterBelow(uint256 limit){
        if(counter>limit){
            revert ExceesLimit(limit);
        }
        _;
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 4】构造函数 + 初始化
    // ═════════════════════════════════════════════════════════════════════
    constructor() {
        owner = msg.sender;
        paused = false;
        counter = 0;
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 5】if / else / else if 条件语句
    //
    //   • 语法和 JavaScript / C++ 几乎一样；
    //   • 但注意：Solidity 没有 switch/case！
    //   • 条件必须是 bool 类型，不能写 if (x) 当 x 是 uint256。
    //
    //   💡 在合约里 if/else 最常见的用途：
    //     - 根据不同状态做不同操作
    //     - 参数校验后分流
    // ═════════════════════════════════════════════════════════════════════

    /// 根据分数返回等级：A / B / C / D
    function getGrade(uint256 score) external pure returns (string memory) {
        if (score >= 90) {
            return "A";
        } else if (score >= 80) {
            return "B";
        } else if (score >= 60) {
            return "C";
        } else {
            return "D";
        }
    }

    /// 三元运算符：Solidity 也支持 condition ? a : b
    function max(uint256 a, uint256 b) external pure returns (uint256) {
        return a >= b ? a : b;
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 6】for / while 循环
    //
    //   • 语法同 C/JS；
    //   • ⚠️ 重要警告：链上循环有 gas 上限！
    //     如果数组长度不可控（用户可以无限 push），循环可能 gas 超限 revert。
    //     这叫"unbounded loop 攻击面"，是审计中最常见的 Medium 级问题。
    //
    //   • 最佳实践：
    //     1) 循环只用于已知上限的小数组
    //     2) 如果需要遍历大量数据，考虑链下索引（event + subgraph）
    //     3) 不要在循环里做高 gas 操作（如写 storage）
    // ═════════════════════════════════════════════════════════════════════

    /// 求 scores 数组之和（演示 for 循环读 storage 数组）
    function totalScore() external view returns (uint256 total) {
        // 如果可以被所有人push，这里score遍历会消耗完所有的gas
        for (uint256 i = 0; i < scores.length; i++) {
            total += scores[i];
        }
        // 注意：total 在 returns 里声明了，会自动返回，不用写 return
    }

    /// 找到 scores 里第一个大于 threshold 的值（演示 while + break）
    function findFirstAbove(uint256 threshold) external view returns (uint256) {
        uint256 i = 0;
        while (i < scores.length) {
            if (scores[i] > threshold) {
                return scores[i];
            }
            i++;
            // 也可以用 unchecked { i++; } 省一点 gas（跳过溢出检查）
        }
        revert NoScores();  // 没找到就 revert
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 7】require / revert / assert —— 三种错误处理方式
    //
    //   ▶ require(condition, "msg")
    //     - 条件不满足就回滚 + 返回错误信息
    //     - 最常用于"输入校验"和"前置条件检查"
    //     - 会退还剩余 gas
    //
    //   ▶ revert("msg") 或 revert CustomError()
    //     - 无条件回滚，通常和 if 搭配使用
    //     - 更灵活：可以用自定义错误省 gas
    //
    //   ▶ assert(condition)
    //     - 用于"不应该发生"的内部逻辑错误
    //     - 0.8.0+ assert 失败也退还剩余 gas（以前会吃掉全部 gas）
    //     - 审计师看到 assert 就知道"这里作者认为永远不会 false"
    //
    //   💡 选择建议：
    //     - 外部输入校验 → require 或 revert + custom error
    //     - 内部不变量   → assert
    //     - 想省 gas     → revert + custom error（不带字符串）
    // ═════════════════════════════════════════════════════════════════════

    /// 演示 require：添加分数前校验
    function addScore(uint256 score) external whenNotPaused {
//        require(score <= 100, "score must be <= 100");
        if(score>100){
            revert NotExceed("score must be <= 100");
        }
        scores.push(score);
        emit ScoreAdded(score);
    }

    /// 演示 revert + custom error：更精细的校验
    function addScoreStrict(uint256 score) external whenNotPaused {
        if (score == 0) {
            revert InvalidScore(score, "score cannot be zero");
        }
        if (score > 100) {
            revert InvalidScore(score, "score exceeds maximum");
        }
        scores.push(score);
        emit ScoreAdded(score);
    }

    /// 演示 assert：counter 溢出理论上不可能（uint256 很大）
    function increment() external whenNotPaused onlyWhenCounterBelow(100) {
        uint256 oldCounter = counter;
        counter += 1;
        emit CounterIncremented(msg.sender, counter);

        // 这个 assert 在正常情况下永远不会失败
        // （除非 uint256 溢出，但那需要 2^256 次调用）
        assert(counter > oldCounter);
    }


    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 8】modifier 叠加使用 + 管理函数
    //
    //   • 一个函数可以写多个 modifier：
    //     function foo() external onlyOwner whenNotPaused { ... }
    //     执行顺序：onlyOwner 的 _; 前代码 → whenNotPaused 的 _; 前代码 → 函数体
    //
    //   • 这是最常见的"权限 + 状态"双重守卫模式。
    // ═════════════════════════════════════════════════════════════════════

    /// 暂停合约（只有 owner 能调）
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    /// 恢复合约（只有 owner 能调）
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// 添加白名单（onlyOwner + whenNotPaused 叠加）
    function addToWhitelist(address user) external onlyOwner whenNotPaused {
        whitelist[user] = true;
    }
    function removeWhiteList( address user) external onlyOwner{
        delete whitelist[user];
    }

    /// 只有白名单用户才能调用的"VIP 功能"
    function vipIncrement() external onlyWhitelisted whenNotPaused {
        counter += 10;
        emit CounterIncremented(msg.sender, counter);
    }

    /// 查看 scores 数组长度
    function scoresLength() external view returns (uint256) {
        return scores.length;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎓 本文件涵盖的 8 个知识点：
//   1. 自定义错误（Custom Errors）—— 省 gas 的错误处理方式
//   2. 事件（Event）—— 配合业务逻辑记录链上日志
//   3. modifier 修饰符 —— 函数的前置/后置守卫
//   4. 构造函数初始化
//   5. if / else / 三元运算符 —— 条件分支
//   6. for / while / break —— 循环（注意 gas 上限！）
//   7. require / revert / assert —— 三种错误处理对比
//   8. modifier 叠加 —— 权限 + 状态双重守卫模式
//
// 下一步：去看 ControlFlow.t.sol，从测试里验证这些知识点。
// ─────────────────────────────────────────────────────────────────────────────
