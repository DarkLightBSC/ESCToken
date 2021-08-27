// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.7.3;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GDLToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Gold", "GLD") {
        _mint(msg.sender, initialSupply);
    }
}