// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// L8 · ERC20 代币实战
//
// 💡 本文件从零手写一个完整的 ERC20 代币合约，深入理解代币标准的每一个细节：
//    接口定义、余额管理、转账机制、授权机制（approve/transferFrom）、
//    铸造/销毁、总量控制、以及实际 DeFi 中的应用场景。
//
// Java 程序员注意：
//   - ERC20 类似 Java 的一个标准接口（如 Comparable / Serializable）
//   - 所有 DEX / 借贷协议都依赖这个接口来操作代币
//   - approve + transferFrom = "我授权你从我账户扣钱"（类似银行代扣协议）
//   - 代币不是 ETH！代币是合约里的一个 mapping(address => uint256)
// ─────────────────────────────────────────────────────────────────────────────

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 1】ERC20 是什么？
//
//   ERC20 = Ethereum Request for Comments #20
//   它是一个**接口标准**，定义了"代币合约必须实现哪些函数和事件"。
//
//   为什么需要标准？
//     - 让所有钱包（MetaMask）能识别并显示你的代币
//     - 让所有 DEX（Uniswap）能交易你的代币
//     - 让所有 DeFi 协议能组合使用你的代币
//
//   本质：代币 ≠ ETH。代币只是合约里的数字记录：
//     mapping(address => uint256) balanceOf;  // 谁持有多少代币
//
//   💡 类比 Java：ERC20 ≈ 一个 interface TokenStandard { ... }
//     所有代币合约 implements 这个接口，钱包/DEX 只面向接口编程。
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 2】ERC20 接口的 6 个必须函数 + 2 个必须事件
//
//   函数：
//     1. totalSupply()          → 代币总供应量
//     2. balanceOf(address)     → 某地址的代币余额
//     3. transfer(to, amount)   → 直接转账（自己转给别人）
//     4. approve(spender, amount)     → 授权额度
//     5. allowance(owner, spender)    → 查询授权额度
//     6. transferFrom(from, to, amount) → 代扣（第三方用授权额度转账）
//
//   事件：
//     1. Transfer(from, to, amount)    → 转账时必须触发
//     2. Approval(owner, spender, amount) → 授权时必须触发
//
//   可选函数（ERC20Metadata）：
//     - name()     → 代币名称（如 "Tether USD"）
//     - symbol()   → 代币符号（如 "USDT"）
//     - decimals() → 小数位（通常 18）
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 3】approve + transferFrom 授权机制
//
//   场景：用户想在 Uniswap 上卖 100 USDT
//     1. 用户调用 USDT.approve(uniswapRouter, 100)  → "我授权 Uniswap 可以从我这扣 100"
//     2. Uniswap 调用 USDT.transferFrom(用户, Uniswap, 100) → "Uniswap 真的扣了 100"
//
//   为什么不直接 transfer？
//     因为 Uniswap 合约不是用户，它没法替用户调 transfer。
//     必须由**合约自己**调 transferFrom 来拿钱，前提是用户已经 approve 了。
//
//   💡 类比 Java：
//     approve ≈ 签署银行代扣协议（"我允许电力公司每月从我账户扣最多 500 元"）
//     transferFrom ≈ 电力公司真的执行了代扣操作
//     allowance ≈ 查询"还剩多少代扣额度"
//
//   安全注意：
//     - approve 设置的是**覆盖**值，不是增加值
//     - 如果先 approve(100)，再 approve(200)，最终额度是 200（不是 300）
//     - 恶意 spender 可能在两次 approve 之间快速 transferFrom → "approve 竞态攻击"
//     - 解决方案：先 approve(0)，再 approve(newAmount)
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 4】decimals 与精度
//
//   代币没有小数！EVM 只有整数运算。所谓"小数"是前端显示的约定：
//     - decimals = 18 → 合约里的 1e18 = 前端显示的 "1.0" 个代币
//     - decimals = 6  → 合约里的 1e6  = 前端显示的 "1.0" 个代币（USDT/USDC）
//
//   为什么大多数用 18？
//     因为 1 ETH = 1e18 wei，保持一致方便计算。
//
//   💡 类比：人民币在银行系统里以"分"为单位存储，显示时除以 100。
//     代币以"最小单位"存储，显示时除以 10^decimals。
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 5】铸造（mint）与销毁（burn）
//
//   - mint：凭空创造代币（totalSupply 增加）
//     典型场景：初始分配、质押奖励、流动性挖矿
//
//   - burn：永久销毁代币（totalSupply 减少）
//     典型场景：回购销毁、交易手续费燃烧、通缩机制
//
//   铸造时 Transfer 事件的 from = address(0)
//   销毁时 Transfer 事件的 to   = address(0)
//
//   💡 类比：mint = 央行印钞，burn = 碎钞机
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 6】ERC20 在 DeFi 中的实际应用
//
//   - DEX（Uniswap）：approve → swap（底层 transferFrom）
//   - 借贷（Aave）：approve → deposit → 得到 aToken
//   - 质押（Staking）：approve → stake → 得到奖励代币
//   - 空投（Airdrop）：owner mint → 批量 transfer
//   - ICO/IDO：用户 transfer ETH → 合约 mint 代币给用户
//
//   所有 DeFi 交互的第一步几乎都是 approve！
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 7】常见安全问题
//
//   1. approve 竞态攻击（前面提过）
//   2. 假代币攻击：部署同名代币，冒充正版
//   3. 无限 approve：很多 DApp 让用户 approve(type(uint256).max)
//      优点：一次授权永久使用，省 gas
//      缺点：如果 DApp 被黑，可以掏空你所有代币
//   4. transfer 到合约地址：如果合约没处理 ERC20，代币永远卡死
//      → ERC223/ERC777 试图解决，但引入了新问题
//   5. 重入风险：ERC777 的 hook 机制可能被利用
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 8】实现模式：继承 vs 手写
//
//   生产环境推荐：继承 OpenZeppelin 的 ERC20
//     import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//     contract MyToken is ERC20 { ... }
//
//   本课教学目的：手写完整实现，理解每一行代码的作用
//
//   OpenZeppelin 额外提供：
//     - ERC20Burnable：公开的 burn 函数
//     - ERC20Capped：最大供应量限制
//     - ERC20Pausable：紧急暂停
//     - ERC20Permit：无 gas 授权（EIP-2612）
//     - ERC20Votes：治理投票
// ═════════════════════════════════════════════════════════════════════════════


// ─────────────────────────────────────────────────────────────────────────────
// 接口定义
// ─────────────────────────────────────────────────────────────────────────────

/// @title IERC20 标准接口
interface IERC20 {
    // ───── 事件 ─────
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ───── 查询函数 ─────
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    // ───── 操作函数 ─────
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title IERC20Metadata 扩展接口
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}


// ─────────────────────────────────────────────────────────────────────────────
// 完整手写 ERC20 实现
// ─────────────────────────────────────────────────────────────────────────────

/// @title MyERC20 - 从零手写的完整 ERC20 代币
/// @dev 实现 IERC20 + IERC20Metadata，包含 mint/burn 功能
contract MyERC20 is IERC20Metadata {
    // ───── 状态变量 ─────

    /// 代币名称（如 "My Token"）
    string private _name;

    /// 代币符号（如 "MTK"）
    string private _symbol;

    /// 小数位数（通常 18）
    uint8 private _decimals;

    /// 总供应量
    uint256 private _totalSupply;

    /// 余额映射：谁持有多少代币
    mapping(address => uint256) private _balances;

    /// 授权映射：owner 授权 spender 可以花多少
    /// _allowances[owner][spender] = amount
    mapping(address => mapping(address => uint256)) private _allowances;

    /// 合约部署者（拥有 mint 权限）
    address public owner;

    // ───── 自定义错误 ─────
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
    error OwnableUnauthorized(address caller);
    error ERC20ExceedsCap(uint256 attempted, uint256 cap);

    // ───── 铸造上限 ─────
    uint256 public immutable cap;

    // ═════════════════════════════════════════════════════════════════════
    // 构造函数
    // ═════════════════════════════════════════════════════════════════════

    /// @param name_ 代币名称
    /// @param symbol_ 代币符号
    /// @param decimals_ 小数位数
    /// @param cap_ 最大供应量（0 表示无上限）
    /// @param initialSupply 初始铸造量（给 deployer）
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 cap_,
        uint256 initialSupply
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        cap = cap_;
        owner = msg.sender;

        // 初始铸造
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // Metadata 函数（ERC20Metadata）
    // ═════════════════════════════════════════════════════════════════════

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    // ═════════════════════════════════════════════════════════════════════
    // 查询函数
    // ═════════════════════════════════════════════════════════════════════

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address tokenOwner, address spender) external view override returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 2 实战】transfer - 直接转账
    // ═════════════════════════════════════════════════════════════════════

    /// @notice 调用者直接转代币给 to
    /// @dev 必须触发 Transfer 事件，失败必须 revert（不能只返回 false）
    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 3 实战】approve - 授权额度
    // ═════════════════════════════════════════════════════════════════════

    /// @notice 调用者授权 spender 可以花费 amount 个代币
    /// @dev 这是"覆盖"操作，不是"增加"。必须触发 Approval 事件
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 3 实战】transferFrom - 代扣
    // ═════════════════════════════════════════════════════════════════════

    /// @notice spender 从 from 账户转 amount 代币给 to
    /// @dev 必须先有足够的 allowance，执行后自动扣减 allowance
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        // 1. 检查并扣减授权额度
        _spendAllowance(from, msg.sender, amount);
        // 2. 执行转账
        _transfer(from, to, amount);
        return true;
    }

    // ═════════════════════════════════════════════════════════════════════
    // 【知识点 5 实战】mint 和 burn
    // ═════════════════════════════════════════════════════════════════════

    /// @notice 铸造新代币（仅 owner）
    function mint(address to, uint256 amount) external {
        if (msg.sender != owner) revert OwnableUnauthorized(msg.sender);
        _mint(to, amount);
    }

    /// @notice 销毁自己的代币
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice 从授权账户销毁代币
    function burnFrom(address from, uint256 amount) external {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 便捷函数：增加/减少授权（避免竞态攻击）
    // ═════════════════════════════════════════════════════════════════════

    /// @notice 增加 spender 的授权额度
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    /// @notice 减少 spender 的授权额度
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased below zero");
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    // ═════════════════════════════════════════════════════════════════════
    // 内部函数（核心逻辑）
    // ═════════════════════════════════════════════════════════════════════

    /// @dev 转账核心逻辑（CEI 模式）
    function _transfer(address from, address to, uint256 amount) internal {
        // Checks
        if (from == address(0)) revert ERC20InvalidSender(address(0));
        if (to == address(0)) revert ERC20InvalidReceiver(address(0));

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert ERC20InsufficientBalance(from, fromBalance, amount);
        }

        // Effects
        unchecked {
            // 不会下溢：已经检查 fromBalance >= amount
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        // 触发事件
        emit Transfer(from, to, amount);
    }

    /// @dev 铸造核心逻辑
    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ERC20InvalidReceiver(address(0));

        // 检查铸造上限
        if (cap > 0 && _totalSupply + amount > cap) {
            revert ERC20ExceedsCap(_totalSupply + amount, cap);
        }

        _totalSupply += amount;
        _balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    /// @dev 销毁核心逻辑
    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ERC20InvalidSender(address(0));

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert ERC20InsufficientBalance(from, fromBalance, amount);
        }

        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(from, address(0), amount);
    }

    /// @dev 授权核心逻辑
    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        if (tokenOwner == address(0)) revert ERC20InvalidApprover(address(0));
        if (spender == address(0)) revert ERC20InvalidSpender(address(0));

        _allowances[tokenOwner][spender] = amount;

        emit Approval(tokenOwner, spender, amount);
    }

    /// @dev 消费授权额度
    function _spendAllowance(address tokenOwner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[tokenOwner][spender];

        // 无限授权不扣减（type(uint256).max 表示无限）
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
            }
            unchecked {
                _approve(tokenOwner, spender, currentAllowance - amount);
            }
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 实际应用示例：简单的 ICO 合约
// ─────────────────────────────────────────────────────────────────────────────

/// @title SimpleICO - 用 ETH 购买代币的简单 ICO 合约
/// @dev 演示 ERC20 在实际场景中的使用
contract SimpleICO {
    MyERC20 public token;
    address public owner;
    uint256 public price;       // 每个代币的价格（wei/token，最小单位）
    uint256 public totalRaised; // 总共筹集了多少 ETH
    bool public active;         // ICO 是否进行中

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event ICOStatusChanged(bool active);

    error ICONotActive();
    error InsufficientPayment();
    error NotOwner();
    error WithdrawFailed();

    constructor(address _token, uint256 _price) {
        token = MyERC20(_token);
        owner = msg.sender;
        price = _price;
        active = true;
    }

    /// @notice 用 ETH 购买代币
    function buyTokens() external payable {
        if (!active) revert ICONotActive();
        if (msg.value == 0) revert InsufficientPayment();

        // 计算能买多少代币
        // 如果 price = 0.001 ether per token (1e15 wei per 1e18 token unit)
        // 用户付了 1 ether = 1e18 wei → 得到 1e18 / 1e15 * 1e18 = 1000 tokens
        uint256 tokenAmount = (msg.value * 10 ** token.decimals()) / price;

        // 从 ICO 合约的余额中转代币给买家
        // 前提：owner 需要先把代币 transfer 到这个 ICO 合约
        token.transfer(msg.sender, tokenAmount);

        totalRaised += msg.value;

        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }

    /// @notice owner 提取筹集的 ETH
    function withdraw() external {
        if (msg.sender != owner) revert NotOwner();
        (bool ok, ) = owner.call{value: address(this).balance}("");
        if (!ok) revert WithdrawFailed();
    }

    /// @notice 开启/关闭 ICO
    function setActive(bool _active) external {
        if (msg.sender != owner) revert NotOwner();
        active = _active;
        emit ICOStatusChanged(_active);
    }

    /// @notice 查看 ICO 合约还剩多少代币可卖
    function remainingTokens() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
