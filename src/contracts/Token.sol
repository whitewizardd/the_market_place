// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function runMint() external {
        _mint(msg.sender, 3 ether);
    }

    function auctionMint() external {
        _mint(msg.sender, 100 wei);
    }
}
