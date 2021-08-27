const IERC20_ABI = [
    // Read-Only Functions
    "function balanceOf(address owner) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function symbol() view returns (string)",

    // Authenticated Functions
    "function transfer(address to, uint amount) returns (boolean)",

    // Events
    "event Transfer(address indexed from, address indexed to, uint amount)",

    "function approve(address spender, uint value) external returns (bool)",

    "function totalSupply() external view returns (uint)",

    "function allowance(address owner, address spender) public view returns (uint256)"
];


export {IERC20_ABI};