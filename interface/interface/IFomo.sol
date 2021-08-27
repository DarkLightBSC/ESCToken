//SPDX-License-Identifier: Unlicensed

pragma solidity >=0.7.3;


interface IFomo {
    function transferNotify(address user) external;
    function swap() external;
}