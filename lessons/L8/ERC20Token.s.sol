// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./ERC20Token.sol";

/// @title L8 部署脚本
contract ERC20TokenScript is Script {
    function run() external {
        vm.startBroadcast();

        // 部署代币：名称 "My Token"，符号 "MTK"，18位小数，上限1000万，初始100万
        MyERC20 token = new MyERC20(
            "My Token",
            "MTK",
            18,
            10_000_000 * 1e18,  // cap
            1_000_000 * 1e18    // initial supply
        );
        console.log("MyERC20 deployed at:", address(token));
        console.log("Total supply:", token.totalSupply());

        // 部署 ICO 合约：每个代币 0.001 ETH
        SimpleICO ico = new SimpleICO(address(token), 0.001 ether);
        console.log("SimpleICO deployed at:", address(ico));

        // 转 10000 代币给 ICO 合约用于售卖
        token.transfer(address(ico), 10_000 * 1e18);
        console.log("Transferred 10000 tokens to ICO");

        vm.stopBroadcast();
    }
}
