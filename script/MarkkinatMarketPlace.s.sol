// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/contracts/MarkkinatMarketPlace.sol";

contract DeployMarkkinatMarketPlace is Script {
    address DAO_ADDRESS = 0xee53D67596baf6c437D399493Ac0499A1459c626;
    address DAO_CONTRACT = 0xa2FB4316387988559132626df7f68F6A40eCa46d;

    function setUp() public {}

    function run() external returns (MarkkinatMarketPlace) {
        vm.startBroadcast();

        MarkkinatMarketPlace markkinatMarketPlace = new MarkkinatMarketPlace(DAO_CONTRACT, DAO_ADDRESS);

        vm.stopBroadcast();
        return markkinatMarketPlace;
    }
}
