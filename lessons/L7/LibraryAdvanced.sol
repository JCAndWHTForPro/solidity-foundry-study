// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// L7 · Library 与高级语法
//
// 💡 本文件深入讲解 Solidity 的 Library 机制和高级语法特性：
//    library 定义与使用、using for、struct 高级用法、
//    用户自定义值类型（type）、ABI 编解码、try/catch。
//
// Java 程序员注意：
//   - Library 类似 Java 的 static 工具类（如 Collections / Math）
//   - using for 类似 Kotlin 的扩展函数
//   - abi.encode 类似 Java 的序列化/反序列化
//   - try/catch 语法与 Java 类似但只能用于外部调用
// ─────────────────────────────────────────────────────────────────────────────

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 1】Library 基本概念与定义
//
//   Library 是一种特殊的合约：
//     - 不能有状态变量（没有 storage）
//     - 不能接收 ETH（没有 receive / fallback）
//     - 不能被继承，也不能继承别人
//     - 不能被销毁（没有 selfdestruct）
//     - 所有函数都是"无状态工具函数"
//
//   Library 的两种调用方式：
//     1. 直接调用：MathLib.add(a, b)
//     2. 附加到类型：using MathLib for uint256; → a.add(b)
//
//   💡 类比 Java：
//     library MathLib  ≈  public class MathUtils { static int add(int a, int b) {...} }
//     MathLib.add(a,b) ≈  MathUtils.add(a, b)
//     a.add(b)         ≈  Kotlin 扩展函数 fun Int.add(b: Int): Int
//
//   Library 函数的可见性与部署：
//     - internal 函数：编译时内联到调用合约（不单独部署，最常用）
//     - public/external 函数：Library 单独部署，调用合约通过 DELEGATECALL 调用
//       （实际开发中很少用，除非 Library 很大想节省合约 size）
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 2】using for 语法糖
//
//   using A for B; — 把 Library A 的所有函数"附加"到类型 B 上
//
//   规则：
//     - Library 函数的第一个参数必须是 B 类型
//     - 可以用 using A for *; 附加到所有类型（不推荐，太宽泛）
//     - 可以指定具体函数：using { MathLib.add, MathLib.sub } for uint256;
//     - Solidity 0.8.13+ 支持在文件级别 using，作用于整个文件
//
//   💡 类比：
//     using MathLib for uint256;   ≈   给 uint256 类型"装上"了 MathLib 的方法
//     uint256 x = 10; x.add(5);   ≈   Kotlin: 10.add(5)
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 3】Struct 高级用法
//
//   struct 可以：
//     - 嵌套其他 struct
//     - 作为 mapping 的 value
//     - 在 Library 中操作（传入 storage pointer）
//     - 在 memory 中创建临时实例
//
//   storage pointer（引用传递）：
//     function _getUser(mapping(address => User) storage users, address addr)
//       → 返回的是 storage 引用，修改它等于直接修改原始数据
//
//   💡 类比 Java：
//     storage pointer ≈ Java 的对象引用（修改引用指向的对象 = 修改原始对象）
//     memory struct   ≈ Java 的 new Object()（独立副本）
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 4】用户自定义值类型（User Defined Value Types）
//
//   Solidity 0.8.8+ 引入：type MyType is uint256;
//
//   特点：
//     - 创建了一个全新类型，与底层类型不能隐式转换
//     - 必须用 MyType.wrap(x) 和 MyType.unwrap(y) 显式转换
//     - 编译期零开销（EVM 层面还是 uint256）
//     - 防止不同语义的值混用（如 USD 和 ETH 金额）
//
//   💡 类比 Java：
//     type USD is uint256;  ≈  record USD(BigInteger value) {}
//     编译期强类型检查，防止把美元当成以太币用
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 5】ABI 编解码
//
//   ABI（Application Binary Interface）= 合约函数调用的序列化协议
//
//   编码函数：
//     - abi.encode(args...)          → 标准 ABI 编码（带填充到 32 字节）
//     - abi.encodePacked(args...)    → 紧凑编码（不填充，更短但有哈希碰撞风险）
//     - abi.encodeWithSignature(sig, args...) → 函数选择器 + 参数编码
//     - abi.encodeWithSelector(selector, args...) → 同上，但直接传 bytes4
//
//   解码函数：
//     - abi.decode(data, (types...)) → 将 bytes 解码回具体类型
//
//   💡 类比 Java：
//     abi.encode    ≈  ObjectOutputStream（序列化）
//     abi.decode    ≈  ObjectInputStream（反序列化）
//     abi.encodePacked ≈ 紧凑的 Protocol Buffers 序列化
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 6】函数选择器（Function Selector）
//
//   函数选择器 = keccak256(函数签名) 的前 4 字节
//
//   例如：
//     "transfer(address,uint256)" → keccak256 → 前4字节 = 0xa9059cbb
//
//   msg.data 的结构：
//     [4字节选择器][32字节参数1][32字节参数2]...
//
//   用途：
//     - 底层调用时手动构造 calldata
//     - 代理合约（Proxy）转发调用
//     - 验证调用的函数签名
//
//   获取方式：
//     - bytes4(keccak256("functionName(type1,type2)"))
//     - this.functionName.selector（推荐，编译期计算）
//     - type(InterfaceName).interfaceId（接口的所有函数选择器 XOR）
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 7】try/catch 错误处理
//
//   Solidity 的 try/catch 只能用于外部调用（external call）和合约创建。
//
//   语法：
//     try externalContract.func(args) returns (ReturnType result) {
//         // 成功处理
//     } catch Error(string memory reason) {
//         // require/revert with string
//     } catch Panic(uint errorCode) {
//         // assert 失败 / 除零 / 溢出等
//     } catch (bytes memory lowLevelData) {
//         // 其他未知错误（自定义 error 等）
//     }
//
//   💡 类比 Java：
//     try { ... } catch (IllegalArgumentException e) { ... }  ≈  catch Error(string)
//     try { ... } catch (ArithmeticException e) { ... }       ≈  catch Panic(uint)
//     try { ... } catch (Exception e) { ... }                 ≈  catch (bytes)
//
//   ⚠️ 注意：内部函数调用不能用 try/catch，只能用 require/revert
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// 【知识点 8】常量表达式与编译期计算
//
//   - keccak256 可以在编译期计算常量哈希
//   - bytes4(...) 可以在编译期提取选择器
//   - constant 变量在编译期求值，不占 storage
//
//   实用模式：
//     bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
//     bytes4 public constant TRANSFER_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));
// ═════════════════════════════════════════════════════════════════════════════


// ─────────────────────────────────────────────────────────────────────────────
// 实战代码开始
// ─────────────────────────────────────────────────────────────────────────────

/// @title 数学工具库：演示 Library 基本定义
/// @dev 所有函数都是 internal（编译时内联，不需要单独部署）
library MathLib {
    /// @notice 安全加法（0.8+ 本身就溢出检查，这里主要演示 Library 写法）
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /// @notice 安全减法
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "MathLib: underflow");
        return a - b;
    }

    /// @notice 百分比计算：(value * percentage) / 100
    function percentage(uint256 value, uint256 pct) internal pure returns (uint256) {
        return (value * pct) / 100;
    }

    /// @notice 返回两者中的最大值
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /// @notice 返回两者中的最小值
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }
}


/// @title 数组工具库：演示对数组的 Library 操作
library ArrayLib {
    /// @notice 判断数组是否包含某个值
    function contains(uint256[] storage arr, uint256 value) internal view returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == value) return true;
        }
        return false;
    }

    /// @notice 删除指定索引的元素（用最后一个元素覆盖，不保序但 O(1)）
    function removeUnordered(uint256[] storage arr, uint256 index) internal {
        require(index < arr.length, "ArrayLib: out of bounds");
        arr[index] = arr[arr.length - 1];
        arr.pop();
    }

    /// @notice 求数组总和
    function sum(uint256[] storage arr) internal view returns (uint256 total) {
        for (uint256 i = 0; i < arr.length; i++) {
            total += arr[i];
        }
    }
}


/// @title 字符串工具库：演示 bytes 操作
library StringLib {
    /// @notice 计算字符串长度（字节数，不是字符数）
    function length(string memory s) internal pure returns (uint256) {
        return bytes(s).length;
    }

    /// @notice 拼接两个字符串
    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    /// @notice 判断字符串是否为空
    function isEmpty(string memory s) internal pure returns (bool) {
        return bytes(s).length == 0;
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 【知识点 4 实战】用户自定义值类型
// ─────────────────────────────────────────────────────────────────────────────

/// @dev 定义 USD 类型：表示美元金额（单位：分，即 1 USD = 100）
type USD is uint256;

/// @dev 定义 TokenAmount 类型：表示代币数量（单位：最小单位）
type TokenAmount is uint256;

/// @title USD 操作库
library USDLib {
    function add(USD a, USD b) internal pure returns (USD) {
        return USD.wrap(USD.unwrap(a) + USD.unwrap(b));
    }

    function sub(USD a, USD b) internal pure returns (USD) {
        require(USD.unwrap(a) >= USD.unwrap(b), "USDLib: underflow");
        return USD.wrap(USD.unwrap(a) - USD.unwrap(b));
    }

    function isZero(USD a) internal pure returns (bool) {
        return USD.unwrap(a) == 0;
    }

    function toUint(USD a) internal pure returns (uint256) {
        return USD.unwrap(a);
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 主合约：综合运用所有知识点
// ─────────────────────────────────────────────────────────────────────────────

/// @title LibraryDemo - 综合演示 Library、using for、struct、ABI 编解码
contract LibraryDemo {
    // 【知识点 2】using for：把 Library 附加到类型
    using MathLib for uint256;
    using ArrayLib for uint256[];
    using StringLib for string;
    using USDLib for USD;

    // ───── Struct 定义 ─────
    struct UserProfile {
        string name;
        uint256 age;
        uint256 score;
        bool active;
    }

    struct Order {
        address buyer;
        USD price;
        uint256 timestamp;
        string item;
    }

    // ───── 状态变量 ─────
    mapping(address => UserProfile) public profiles;
    mapping(uint256 => Order) public orders;
    uint256[] public scores;
    uint256 public nextOrderId;

    // ───── 事件 ─────
    event ProfileCreated(address indexed user, string name);
    event OrderPlaced(uint256 indexed orderId, address indexed buyer, uint256 price);
    event ScoreAdded(address indexed user, uint256 score, uint256 total);

    // ───── 自定义错误 ─────
    error ProfileNotFound(address user);
    error InvalidName(string name);
    error ScoreOutOfRange(uint256 score);

    // ───── 编译期常量 ─────
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes4 public constant PROFILE_SELECTOR = bytes4(keccak256("createProfile(string,uint256)"));

    // ═════════════════════════════════════════════════════════════════════
    // using for 实战：uint256 扩展方法
    // ═════════════════════════════════════════════════════════════════════

    /// @notice 演示 using for 的扩展方法调用
    function mathDemo(uint256 a, uint256 b) external pure returns (
        uint256 sum_,
        uint256 diff,
        uint256 pct,
        uint256 max_,
        uint256 min_
    ) {
        sum_ = a.add(b);          // 等价于 MathLib.add(a, b)
        diff = a.sub(b);          // 等价于 MathLib.sub(a, b)
        pct = a.percentage(10);   // 等价于 MathLib.percentage(a, 10)
        max_ = a.max(b);          // 等价于 MathLib.max(a, b)
        min_ = a.min(b);          // 等价于 MathLib.min(a, b)
    }

    // ═════════════════════════════════════════════════════════════════════
    // Struct + Library 实战
    // ═════════════════════════════════════════════════════════════════════

    /// @notice 创建用户档案
    function createProfile(string calldata name, uint256 age) external {
        if (name.isEmpty()) revert InvalidName(name);

        profiles[msg.sender] = UserProfile({
            name: name,
            age: age,
            score: 0,
            active: true
        });

        emit ProfileCreated(msg.sender, name);
    }

    /// @notice 获取用户档案
    function getProfile(address user) external view returns (
        string memory name,
        uint256 age,
        uint256 score,
        bool active
    ) {
        UserProfile storage p = profiles[user];
        if (bytes(p.name).length == 0) revert ProfileNotFound(user);
        return (p.name, p.age, p.score, p.active);
    }

    /// @notice 给用户加分
    function addScore(address user, uint256 points) external {
        if (points > 100) revert ScoreOutOfRange(points);

        UserProfile storage p = profiles[user];
        if (bytes(p.name).length == 0) revert ProfileNotFound(user);

        p.score = p.score.add(points);  // using MathLib for uint256
        scores.push(points);

        emit ScoreAdded(user, points, p.score);
    }

    // ═════════════════════════════════════════════════════════════════════
    // 数组 Library 实战
    // ═════════════════════════════════════════════════════════════════════

    /// @notice 检查分数是否已存在
    function hasScore(uint256 value) external view returns (bool) {
        return scores.contains(value);  // using ArrayLib for uint256[]
    }

    /// @notice 获取分数总和
    function totalScore() external view returns (uint256) {
        return scores.sum();  // using ArrayLib for uint256[]
    }

    /// @notice 删除指定位置的分数（不保序）
    function removeScore(uint256 index) external {
        scores.removeUnordered(index);  // using ArrayLib for uint256[]
    }

    /// @notice 获取分数数组长度
    function scoresLength() external view returns (uint256) {
        return scores.length;
    }

    // ═════════════════════════════════════════════════════════════════════
    // 自定义值类型 实战
    // ═════════════════════════════════════════════════════════════════════

    /// @notice 使用自定义类型 USD 下单
    function placeOrder(string calldata item, uint256 priceInCents) external {
        USD price = USD.wrap(priceInCents);

        orders[nextOrderId] = Order({
            buyer: msg.sender,
            price: price,
            timestamp: block.timestamp,
            item: item
        });

        emit OrderPlaced(nextOrderId, msg.sender, price.toUint());
        nextOrderId++;
    }

    /// @notice 计算两个订单总价（演示 USD 类型运算）
    function totalPrice(uint256 orderId1, uint256 orderId2) external view returns (uint256) {
        USD p1 = orders[orderId1].price;
        USD p2 = orders[orderId2].price;
        USD total = p1.add(p2);  // using USDLib for USD
        return total.toUint();
    }

    // ═════════════════════════════════════════════════════════════════════
    // ABI 编解码 实战
    // ═════════════════════════════════════════════════════════════════════

    /// @notice 演示 abi.encode：标准编码（每个参数填充到 32 字节）
    function encodeDemo(address addr, uint256 amount) external pure returns (bytes memory) {
        return abi.encode(addr, amount);
    }

    /// @notice 演示 abi.encodePacked：紧凑编码（不填充）
    function encodePackedDemo(address addr, uint256 amount) external pure returns (bytes memory) {
        return abi.encodePacked(addr, amount);
    }

    /// @notice 演示 abi.decode：从 bytes 解码回具体类型
    function decodeDemo(bytes calldata data) external pure returns (address addr, uint256 amount) {
        (addr, amount) = abi.decode(data, (address, uint256));
    }

    /// @notice 演示 abi.encodeWithSignature：构造完整的 calldata
    function encodeCallDemo(address to, uint256 amount) external pure returns (bytes memory) {
        return abi.encodeWithSignature("transfer(address,uint256)", to, amount);
    }

    /// @notice 演示 encodePacked 用于哈希（常见于 Merkle Tree、签名）
    function hashDemo(address addr, uint256 nonce, string calldata message)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(addr, nonce, message));
    }

    // ═════════════════════════════════════════════════════════════════════
    // 函数选择器 实战
    // ═════════════════════════════════════════════════════════════════════

    /// @notice 获取 createProfile 函数的选择器
    function getCreateProfileSelector() external pure returns (bytes4) {
        return this.createProfile.selector;
    }

    /// @notice 手动计算函数选择器
    function computeSelector(string calldata signature) external pure returns (bytes4) {
        return bytes4(keccak256(bytes(signature)));
    }

    /// @notice 验证选择器一致性
    function verifySelector() external pure returns (bool) {
        bytes4 manual = bytes4(keccak256("createProfile(string,uint256)"));
        bytes4 auto_ = LibraryDemo.createProfile.selector;
        return manual == auto_;
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 辅助合约：用于演示 try/catch
// ─────────────────────────────────────────────────────────────────────────────

/// @title 可能失败的外部合约
contract Divider {
    error DivisionByZero();

    function divide(uint256 a, uint256 b) external pure returns (uint256) {
        if (b == 0) revert DivisionByZero();
        return a / b;
    }

    function divideWithMessage(uint256 a, uint256 b) external pure returns (uint256) {
        require(b != 0, "cannot divide by zero");
        return a / b;
    }

    function divideAssert(uint256 a, uint256 b) external pure returns (uint256) {
        assert(b != 0);  // 会触发 Panic
        return a / b;
    }
}


/// @title TryCatchDemo - 演示 try/catch 的各种用法
contract TryCatchDemo {
    Divider public divider;

    event Success(uint256 result);
    event CaughtError(string reason);
    event CaughtPanic(uint256 errorCode);
    event CaughtUnknown(bytes data);

    constructor(address _divider) {
        divider = Divider(_divider);
    }

    /// @notice 演示 try/catch 捕获 require 错误（Error(string)）
    function tryCatchRequire(uint256 a, uint256 b) external returns (string memory) {
        try divider.divideWithMessage(a, b) returns (uint256 result) {
            emit Success(result);
            return "success";
        } catch Error(string memory reason) {
            // 捕获 require(false, "message") 或 revert("message")
            emit CaughtError(reason);
            return reason;
        } catch (bytes memory) {
            emit CaughtUnknown("");
            return "unknown error";
        }
    }

    /// @notice 演示 try/catch 捕获 Panic 错误
    function tryCatchPanic(uint256 a, uint256 b) external returns (uint256 errorCode) {
        try divider.divideAssert(a, b) returns (uint256 result) {
            emit Success(result);
            return 0;
        } catch Panic(uint256 code) {
            // 捕获 assert 失败（Panic(0x01)）或除零（Panic(0x12)）
            emit CaughtPanic(code);
            return code;
        } catch (bytes memory) {
            emit CaughtUnknown("");
            return 999;
        }
    }

    /// @notice 演示 try/catch 捕获自定义 error
    function tryCatchCustom(uint256 a, uint256 b) external returns (bytes memory) {
        try divider.divide(a, b) returns (uint256 result) {
            emit Success(result);
            return "";
        } catch (bytes memory lowLevelData) {
            // 自定义 error 被编码在 lowLevelData 中
            // 前 4 字节是 error selector
            emit CaughtUnknown(lowLevelData);
            return lowLevelData;
        }
    }
}
