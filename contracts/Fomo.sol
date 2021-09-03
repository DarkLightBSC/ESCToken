//SPDX-License-Identifier: Unlicensed

pragma solidity >=0.7.3;

import "../interface/IERC20.sol";
import "../library/safemath.sol";
import "../interface/IUniswapV2Router02.sol";

contract Fomo {
    using SafeMath for uint256;

    address public candidate;
    uint256 public lastTransfer;
    bool inSwap = false;
    IERC20 public esct;
    IERC20 public usdt;// = IERC20(0x55d398326f99059fF775485246999027B3197955);
    uint256 constant public INTERVAL = 5 * 60; // 5 min
    IUniswapV2Router02 public uniswapV2Router;
    address public dev;
    address public constant blackHole = 0x0000000000000000000000000000000000000001;
    address public lastWiner;

    event Reward(address user, uint256 amount);

    constructor (IERC20 _esct, IERC20 _usdt, address _routeAddr) {
        usdt = _usdt;
        esct = _esct;
        uniswapV2Router = IUniswapV2Router02(_routeAddr);
        candidate = msg.sender;
        lastTransfer = block.timestamp;
        dev = msg.sender;
    }

    function timeLeft() external view returns (uint) {
        return INTERVAL - block.timestamp.sub(lastTransfer, "calc interval");
    }

    function getBonus() external view returns (uint) {
        return usdt.balanceOf(address(this));
    }

    function transferNotify(address user) external {
        require(msg.sender == address(esct), "permission denied");
        if (block.timestamp.sub(lastTransfer, "calc interval") > INTERVAL) {
            uint256 reward = usdt.balanceOf(address(this)).div(50); // 2%
            if (reward > 0) {
                usdt.transfer(candidate, reward);
                emit Reward(candidate, reward);

                lastWiner = candidate;
            }
        }
        candidate = user;
        lastTransfer = block.timestamp;
    }

    function swap() public {
        if (inSwap) {
            return;
        }
        inSwap = true;
        uint256 tokenAmount = esct.balanceOf(address(this));
        if (tokenAmount == 0) {
            inSwap = false;
            return;
        }
        address[] memory path = new address[](2);
        path[0] = address(esct);
        path[1] = address(usdt);

        esct.approve(address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        inSwap = false;
    }

    function buyAndBurn() public {
        require(msg.sender == dev, "permission denied");
        // swap first
        swap();

        // buy token
        uint256 amount = usdt.balanceOf(address(this)).mul(10).div(100);
        if (amount == 0) {
            return;
        }

        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(esct);

        usdt.approve(address(uniswapV2Router), amount);
        
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        // burn token
        uint256 tokenBalance = esct.balanceOf(address(this));
        if (tokenBalance > 0) {
            esct.transfer(blackHole, tokenBalance);
        }
    }

    function setDev(address _dev) public {
        require(msg.sender == dev, "permission denied");
        dev = _dev;
    }
}