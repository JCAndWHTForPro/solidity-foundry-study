// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./Inheritance.sol";

/// @notice 部署脚本：一次性部署 L4 的核心合约
contract InheritanceScript is Script {
    function run() external {
        vm.startBroadcast();

        // 1. 部署 Dog
        Dog dog = new Dog("Buddy", "Woof!");
        console.log("Dog deployed at:", address(dog));
        console.log("  name:", dog.name());
        console.log("  speak:", dog.speak());

        // 2. 部署 PetShopV2（多重继承）
        PetShopV2 petShop = new PetShopV2("Luna", "Arf!");
        console.log("PetShopV2 deployed at:", address(petShop));
        console.log("  name:", petShop.name());
        console.log("  description:", petShop.description());

        // 3. 部署 AnimalChecker（面向接口编程）
        AnimalChecker checker = new AnimalChecker();
        console.log("AnimalChecker deployed at:", address(checker));

        // 4. 演示多态调用
        (string memory sound, uint256 legCount) = checker.getInfo(IAnimal(address(dog)));
        console.log("  Dog sound via checker:", sound);
        console.log("  Dog legs via checker:", legCount);

        // 5. 演示注册（Countable + Pausable）
        petShop.register();
        petShop.register();
        console.log("  PetShop count after 2 registers:", petShop.count());

        vm.stopBroadcast();
    }
}
