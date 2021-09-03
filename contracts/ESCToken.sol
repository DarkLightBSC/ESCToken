//SPDX-License-Identifier: Unlicensed
pragma solidity >=0.7.3;

import "../interface/IERC20.sol";
import "../library/safemath.sol";
import "./Ownable.sol";
// import "../library/address.sol";

import "../interface/IUniswapV2Factory.sol";
import "../interface/IUniswapV2Router02.sol";

import "../interface/IFomo.sol";
import "../interface/IWrap.sol";

contract ESCToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    // using Address for address;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;
   
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1000 * 10000 * 10**8 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));

    string private _name = "ESCToken"; 
    string private _symbol = "ESCT"; 
    uint8 private _decimals = 9;
    
    bool private feeIt = true;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    
    uint256 public _maxTxAmount = 500 * 10**8 * 10**9; 
    uint256 private numTokensSellToAddToLiquidity = 5000 * 10**8 * 10**9; 
    address public constant blackHole = 0x0000000000000000000000000000000000000001;
    address private devReceiver;
    address public fomoReceiver;
    uint256 private enterCount = 0;
    uint256 public fomoMin = 1 * 10**8 * 10**9; 
    IERC20 public immutable usdt;// = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IWrap public wrap;
    uint256[5] public feeFomo = [1, 2, 3, 4, 5];
    uint256[5] public feeLiquidity = [3, 5, 7, 9, 11];
    uint256[5] public feeFee = [4, 6, 8, 10, 12];
    
    enum TransferType {TransferStandard, TransferToExcluded, TransferFromExcluded,TransferBothExcluded}

    struct TransferInfo{
        address sender;
        address recipient;
        uint256 tAmount;
        TransferType transferType;
    }
    
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier transferCounter {
        enterCount = enterCount.add(1);
        _;
        enterCount = enterCount.sub(1, "transfer counter");
    }
    
    constructor (address _routeAddr, address _usdtAddr, address _devReceiver) {
        _rOwned[_msgSender()] = _rTotal;
        devReceiver = _devReceiver;

        usdt = IERC20(_usdtAddr);
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_routeAddr);
         // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _usdtAddr);

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        
        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_devReceiver] = true;
        
        emit Transfer(address(0), _msgSender(), _tTotal);
    }
 
    function setDev(address _dev) public {
        require(_msgSender() == devReceiver || _msgSender() == owner(), "fail");
        devReceiver = _dev;
        _isExcludedFromFee[_dev] = true;
    }

    function setFomo(address _fomo) public {
        require(_msgSender() == owner(), "fail");
        fomoReceiver = _fomo;
        _isExcludedFromFee[_fomo] = true;
    }

    function setWrap(IWrap _wrap) public {
        require(_msgSender() == owner(), "fail");
        wrap = _wrap;
        _isExcludedFromFee[address(_wrap)] = true;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        uint256 rAmount = tAmount.mul(_getRate());
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        return rAmount.div(_getRate());
    }

    function excludeFromReward(address account) public onlyOwner() {
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
    
    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }
   
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(
            10**2
        );
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _reflectFee(uint256 rFee) private {
        _rTotal = _rTotal.sub(rFee, "reflect fee");
    }

    function _getTValues(uint256 tAmount, bool isBuy) private view returns (uint256 tTransferAmount, uint256 tFomo, uint256 tDev, uint256 tLiquidity, uint256 tFee) {
        if (!feeIt) {
            return (tAmount, 0, 0, 0, 0);
        }

        if(isBuy){
            tFomo = tAmount.mul(1).div(100);
            tDev = tAmount.mul(2).div(100);
            tLiquidity = tAmount.mul(3).div(100);
            tFee = tAmount.mul(4).div(100);
        } else {
            uint256 healthLevel = getHealthLevel();
            tFomo = tAmount.mul(feeFomo[healthLevel]).div(100);
            tDev = tAmount.div(50);
            tLiquidity = tAmount.mul(feeLiquidity[healthLevel]).div(100);
            tFee = tAmount.mul(feeFee[healthLevel]).div(100);
        }
        tTransferAmount = tAmount.sub(tFomo).sub(tDev).sub(tLiquidity).sub(tFee);
    }

    function _getRValues(uint256 tAmount, uint256 tTransferAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rTransferAmount = tTransferAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]], "sub rSupply");
            tSupply = tSupply.sub(_tOwned[_excluded[i]], "sub tSupply");
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function _takeTax(uint256 tFomo, uint256 tDev, uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rFomo = tFomo.mul(currentRate);
        uint256 rDev = tDev.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
        }
        _rOwned[devReceiver] = _rOwned[devReceiver].add(rDev);
        if (_isExcluded[devReceiver]) {
            _tOwned[devReceiver] = _tOwned[devReceiver].add(tDev);
        }
        _rOwned[fomoReceiver] = _rOwned[fomoReceiver].add(rFomo);
        if (_isExcluded[fomoReceiver]) {
            _tOwned[fomoReceiver] = _tOwned[fomoReceiver].add(tFomo);
        }
    }

    function getHealthLevel() private view returns(uint256) {
        
        uint256 bal = usdt.balanceOf(uniswapV2Pair);
        if (bal <= 100 * 10**4 * 10**18) {
            return 4;
        } else if (bal <= 300 * 10**4 * 10**18) {
            return 3;
        } else if (bal <= 500 * 10**4 * 10**18) {
            return 2;
        } else if (bal <= 1000 * 10**4 * 10**18) {
            return 1;
        }
        return 0;
    }
    
    function removeAllFee() private {
        if (!feeIt) return;
        feeIt = false;
    }
    
    function restoreAllFee() private {
        feeIt = true;
    }
    
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve zero address");
        require(spender != address(0), "ERC20: approve zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function isRealBuy(address from, address to)private view returns(bool){
        return from == uniswapV2Pair && from != owner() && to != owner() && to != fomoReceiver;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private transferCounter {
        require(from != address(0), "ERC20: transfer zero address");
        require(to != address(0), "ERC20: transfer zero address");
        require(amount > 0, "Transfer amount greater than zero");
        if(isRealBuy(from, to)){
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }
            
        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        
        // if(contractTokenBalance >= _maxTxAmount)
        // {
        //     contractTokenBalance = _maxTxAmount;
        // }
        
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        
        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }

        if (enterCount == 1) {
            if (takeFee && from == uniswapV2Pair && amount >= fomoMin) {
                IFomo(fomoReceiver).transferNotify(to);
            }
            if (!inSwapAndLiquify && from != uniswapV2Pair && from != fomoReceiver) {
                IFomo(fomoReceiver).swap();
            }
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half, "sub half");

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        //uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForUsdt(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        // uint256 newBalance = address(this).balance.sub(initialBalance);
        uint256 usdtBalance = usdt.balanceOf(address(this));

        // add liquidity to uniswap
        addLiquidityUsdt(otherHalf, usdtBalance);
        
        emit SwapAndLiquify(half, usdtBalance, otherHalf);
    }

    function swapTokensForUsdt(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(usdt);

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(wrap),
            block.timestamp
        );

        wrap.withdraw();
    }

    function addLiquidityUsdt(uint256 tokenAmount, uint256 usdtAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        usdt.approve(address(uniswapV2Router), usdtAmount);

        uniswapV2Router.addLiquidity(
            address(this),
            address(usdt),
            tokenAmount,
            usdtAmount,
            0,
            0,
            blackHole,
            block.timestamp
        );
    }

    
     //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee)
            removeAllFee();


        TransferInfo memory transferInfo ;
        transferInfo.sender = sender;
        transferInfo.recipient = recipient;
        transferInfo.tAmount = amount;

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            // _transferFromExcluded(sender, recipient, amount);
            transferInfo.transferType = TransferType.TransferFromExcluded;
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            // _transferToExcluded(sender, recipient, amount);
            transferInfo.transferType = TransferType.TransferToExcluded;
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            // _transferStandard(sender, recipient, amount);
            transferInfo.transferType = TransferType.TransferStandard;
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            // _transferBothExcluded(sender, recipient, amount);
            transferInfo.transferType = TransferType.TransferBothExcluded;
        } else {
            // _transferStandard(sender, recipient, amount);
            transferInfo.transferType = TransferType.TransferStandard;
        }

        __transferToken(transferInfo);
        
        if(!takeFee)
            restoreAllFee();
    }

    function __transferToken(TransferInfo memory transferInfo) private {
        bool isBuy = isRealBuy(transferInfo.sender, transferInfo.recipient);

        (uint256 tTransferAmount, uint256 tFomo, uint256 tDev, uint256 tLiquidity, uint256 tFee) = _getTValues(transferInfo.tAmount,isBuy);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(transferInfo.tAmount, tTransferAmount, tFee, _getRate());

        _rOwned[transferInfo.sender] = _rOwned[transferInfo.sender].sub(rAmount, "sub1 rAmount");
        _rOwned[transferInfo.recipient] = _rOwned[transferInfo.recipient].add(rTransferAmount);

        if(transferInfo.transferType == TransferType.TransferToExcluded)  {
            _tOwned[transferInfo.recipient] = _tOwned[transferInfo.recipient].add(tTransferAmount);
        }else if(transferInfo.transferType == TransferType.TransferFromExcluded){
            _tOwned[transferInfo.sender] = _tOwned[transferInfo.sender].sub(transferInfo.tAmount, "sub3 tAmount");
        }else if(transferInfo.transferType == TransferType.TransferBothExcluded){
            _tOwned[transferInfo.sender] = _tOwned[transferInfo.sender].sub(transferInfo.tAmount, "sub4 tAmount");
            _tOwned[transferInfo.recipient] = _tOwned[transferInfo.recipient].add(tTransferAmount);
        }

        _takeTax(tFomo, tDev, tLiquidity);
        _reflectFee(rFee);
        emit Transfer(transferInfo.sender, transferInfo.recipient, tTransferAmount);
        if (tFee > 0) {
            emit Transfer(transferInfo.sender, fomoReceiver, tFomo);
            emit Transfer(transferInfo.sender, devReceiver, tDev);
        }

    }
}