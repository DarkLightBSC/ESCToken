const Route02_ABI = [
    'function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) payable returns (uint256[] memory amounts)',
    'function swapTokensForExactTokens(uint amountOut,uint amountInMax,address[] calldata path,address to,uint deadline) external returns (uint[] memory amounts)',
    'function addLiquidityETH(address token,uint amountTokenDesired,uint amountTokenMin,uint amountETHMin,address to,uint deadline) external payable returns (uint amountToken, uint amountETH, uint liquidity)',
    'function addLiquidity(address tokenA,address tokenB,uint amountADesired,uint amountBDesired,uint amountAMin,uint amountBMin,address to,uint deadline) external returns (uint amountA, uint amountB, uint liquidity)'
];

export {Route02_ABI};