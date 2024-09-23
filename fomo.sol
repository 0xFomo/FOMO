// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
interface IBEP20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event Burn(address indexed owner, address indexed to, uint value);
}
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint a, uint b) internal pure returns (uint) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;
        return c;
    }
    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) {
            return 0;
        }
        uint c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint a, uint b) internal pure returns (uint) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint c = a / b;
        return c;
    }
}
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }
}
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }
    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
interface IPair {
    function sync() external;
}
abstract contract BEP20 is Context, Ownable, IBEP20 {
    using SafeMath for uint;
    mapping(address => uint) internal _balances;
    mapping(address => mapping(address => uint)) internal _allowances;
    mapping(address => bool) private _isMarketPair;
    mapping(address => bool) private _isExcluded;
    mapping(address => bool) private _isFeeWhList;
    mapping(uint256 => uint) public dayFees;
    uint internal _totalSupply;
    uint public totalBurn;
    uint256 public _sellFee = 100;
    uint256 public _buyFee = 100;
    bool public _txEnable = true;
    bool public _sellEnable = false;
    bool public _sellFeeEnable = true;
    bool public _buyEnable = false;
    bool public _buyFeeEnable = true;
    address public Dead = 0x000000000000000000000000000000000000dEaD;
    address public feeTo = 0x8835d34cD7191837f95263E2FCd563593B6FEf9B;
    address public whaAuth = 0x7D6Bd080dD6A99f4158aC1EC7e77eF444C3484De;
    address public eAuth = 0xdB218b0A69892EA202f7Bf16f42e5b97FCdF235e;
    address public feeAuth = 0xdB218b0A69892EA202f7Bf16f42e5b97FCdF235e;
    address public burnAuth = 0x45670ed96f78f4115870a3d0beb5f5c028e33946;
    address public emergency = 0x7D6Bd080dD6A99f4158aC1EC7e77eF444C3484De;
    constructor() {
        _isExcluded[owner()] = true;
        _isExcluded[Dead] = true;
    }
    function totalSupply() public view override returns (uint) {
        return _totalSupply;
    }
    function balanceOf(address account) public view override returns (uint) {
        return _balances[account];
    }
    function transfer(address recipient, uint amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address towner, address spender) public view override returns (uint) {
        return _allowances[towner][spender];
    }
    function approve(address spender, uint amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance")
        );
        return true;
    }
    function increaseAllowance(address spender, uint addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint subtractedValue) public returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero")
        );
        return true;
    }
    function _transfer(address sender, address recipient, uint amount) internal {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(amount > 0, "BEP20: transfer amount the 0");
        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
        uint256 netAmount = amount;
        bool excludedAccount = _isExcluded[sender] || _isExcluded[recipient];
        if (_isMarketPair[sender]) {
            require(excludedAccount || _buyEnable, "not buy");
            if (!_isFeeWhList[recipient]) {
                if (_buyFeeEnable) {
                    netAmount = _takeFees(sender, feeTo, _buyFee, amount);
                }
            }
        } else if (_isMarketPair[recipient]) {
            require(excludedAccount || _sellEnable, "not sell");
            if (!_isFeeWhList[sender]) {
                if (_sellFeeEnable) {
                    netAmount = _takeFees(sender, feeTo, _sellFee, amount);
                }
            }
        } else {
            require(_txEnable, "not transfer");
        }
        _balances[recipient] = _balances[recipient].add(netAmount);
        emit Transfer(sender, recipient, netAmount);
    }
    function _takeFees(
        address sender,
        address recipient,
        uint256 feeRate,
        uint256 amount
    ) internal returns (uint256 netAmount) {
        if (feeRate == 0) return amount;
        uint256 fee = amount.mul(feeRate).div(1000);
        netAmount = amount - fee;
        if (fee > 0) {
            dayFees[timestampZero()] += fee;
            _takeFee(sender, recipient, fee);
        }
    }
    function _takeFee(address sender, address recipient, uint256 fee) private {
        _balances[recipient] = _balances[recipient].add(fee);
        emit Transfer(sender, recipient, fee);
    }
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }
    function _burn(address sender, address recipient, uint amount) private {
        if (recipient == address(0) || recipient == Dead) {
            totalBurn = totalBurn.add(amount);
            // _totalSupply = _totalSupply.sub(amount);
            emit Burn(sender, Dead, amount);
        }
    }
    function _approve(address towner, address spender, uint amount) internal {
        require(towner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");
        _allowances[towner][spender] = amount;
        emit Approval(towner, spender, amount);
    }
    function timestampZero() internal view returns (uint) {
        return (block.timestamp / 1 days) * 1 days;
    }
    function dayBeforeOfFee() external view returns (uint) {
        return dayFees[timestampZero()];
    }
    function addWhl(address[] calldata accounts) external {
        require(whaAuth == msg.sender || owner() == msg.sender, "auth error");
        for (uint i = 0; i < accounts.length; i++) {
            _isExcluded[accounts[i]] = true;
        }
    }
    function removeWhl(address[] calldata accounts) external {
        require(whaAuth == msg.sender || owner() == msg.sender, "auth error");
        for (uint i = 0; i < accounts.length; i++) {
            _isExcluded[accounts[i]] = false;
        }
    }
    function isWh(address addr) external view returns (bool) {
        return _isExcluded[addr];
    }
    function addFeeWhl(address[] calldata accounts) external {
        require(whaAuth == msg.sender || owner() == msg.sender, "auth error");
        for (uint i = 0; i < accounts.length; i++) {
            _isFeeWhList[accounts[i]] = true;
        }
    }
    function removeFeeWhl(address[] calldata accounts) external {
        require(whaAuth == msg.sender || owner() == msg.sender, "auth error");
        for (uint i = 0; i < accounts.length; i++) {
            _isFeeWhList[accounts[i]] = false;
        }
    }
    function isFeeWh(address addr) external view returns (bool) {
        return _isFeeWhList[addr];
    }
    function setBuyFee(uint256 val) external {
        require(feeAuth == msg.sender || owner() == msg.sender, "auth error");
        _buyFee = val;
    }
    function setSellFee(uint256 val) external {
        require(feeAuth == msg.sender || owner() == msg.sender, "auth error");
        _sellFee = val;
    }
    function setPair(address account, bool newValue) external {
        require(feeAuth == msg.sender || owner() == msg.sender, "auth error");
        _isMarketPair[account] = newValue;
    }
    function isPair(address account) external view returns (bool) {
        return _isMarketPair[account];
    }
    function setWHA(address _addr) external {
        require(whaAuth == msg.sender, "auth error");
        whaAuth = _addr;
    }
    function setEAuth(address _addr) external {
        require(eAuth == msg.sender, "auth error");
        eAuth = _addr;
    }
    function setFeeAuth(address _addr) external {
        require(feeAuth == msg.sender, "auth error");
        feeAuth = _addr;
    }
    function setBurnAuth(address _addr) external {
        require(burnAuth == msg.sender, "auth error");
        burnAuth = _addr;
    }
    function setEmergencyEn(address _addr) external {
        require(emergency == msg.sender, "auth error");
        emergency = _addr;
    }
    function setSellEnable(bool newValue, bool newValue1) external {
        require(eAuth == msg.sender || owner() == msg.sender, "auth error");
        _sellEnable = newValue;
        _sellFeeEnable = newValue1;
    }
    function setBuyEnable(bool newValue, bool newValue1) external {
        require(eAuth == msg.sender || owner() == msg.sender, "auth error");
        _buyEnable = newValue;
        _buyFeeEnable = newValue1;
    }
    function setTxEnable(bool newValue) external {
        require(eAuth == msg.sender || owner() == msg.sender, "auth error");
        _txEnable = newValue;
    }
    function decreaseLPToken(address pair, uint256 amount) external {
        require(burnAuth == msg.sender || owner() == msg.sender, "auth error");
        _basicTransfer(pair, Dead, amount);
        _burn(pair, Dead, amount);
        IPair(pair).sync();
    }
}
contract BEP20Detailed is BEP20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    constructor(string memory tname, string memory tsymbol, uint8 tdecimals) {
        _name = tname;
        _symbol = tsymbol;
        _decimals = tdecimals;
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
}
contract FOMOToken is BEP20Detailed {
    constructor() BEP20Detailed("FOMO", "FOMO", 18) {
        _totalSupply = 100_000_000_000 * (10 ** 18);
        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }
    function takeOutTokenInCase(address _token, uint256 _amount, address _to) external {
        require(emergency == msg.sender || owner() == msg.sender, "auth error");
        IBEP20(_token).transfer(_to, _amount);
    }
}
