//SPDX-License-Identifier: Unlicensed

pragma solidity >=0.7.3;

import "../interface/IERC20.sol";

contract Wrap {
    IERC20 public esct;
    IERC20 public usdt;

    constructor(IERC20 _esct, IERC20 _usdt) {
        esct = _esct;
        usdt = _usdt;
    }

    receive() external payable {
    }

    function withdraw() external {
        uint256 usdtBalance = usdt.balanceOf(address(this));
        if (usdtBalance > 0) {
            usdt.transfer(address(esct), usdtBalance);
        }
        uint256 esctBalance = esct.balanceOf(address(this));
        if (esctBalance > 0) {
            esct.transfer(address(esct), esctBalance);
        }
    }
}