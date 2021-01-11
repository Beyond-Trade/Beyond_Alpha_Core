pragma solidity ^0.5.16;

import './SafeMath.sol';
import './Ownable.sol';

interface IUSDSynth {
    function mint(uint256 _value, address _beneficiary) external returns (bool);
    function balanceCheck(address _beneficiary) external view returns(uint256);
    function burn(uint256 _value, address _beneficiary) external;
}

interface IETHSynth {
    function mint(uint256 _value, address _beneficiary) external returns (bool);
    function balanceCheck(address _beneficiary) external view returns(uint256);
    function burn(uint256 _value, address _beneficiary) external;
}

interface IPriceConsumerV3{
    function getLatestPrice(bytes32 _synth) external returns (int);
}

contract Loan is Ownable{
    using SafeMath for uint256;
    
    IUSDSynth public usdSynthToken;
    IETHSynth public ethSynthToken;
    IPriceConsumerV3 public price;
    
    address public beyondExchange;
    
    uint256 public loanFeeRatio = 5;//5%
    uint256 public loanCollatteralRatio = 20;//20%
    uint256 public totalETHb;
    uint256 public totalUSDb;
    uint256 public openLoans = 0;
    
    mapping (address => userLoan) public loanDetails;
    
    struct userLoan{
        //address user;
        uint256 collatteralETHb;
        uint256 loanValueETHb;
        uint256 totalValueAfterLoanFeeETHb;
        uint256 loansOfETHb;
        uint256 collatteralUSDb;
        uint256 loanValueUSDb;
        uint256 totalValueAfterLoanFeeUSDb;
        uint256 loansOfUSDb;
    }
    
    modifier onlyContract{
        require(msg.sender == beyondExchange,"Not Authorized address");
        _;
    }
    
    constructor( IUSDSynth _usdSynthToken, IPriceConsumerV3 _price, IETHSynth _ethSynthToken, address _beyondExchange) public Ownable(msg.sender){
        
        usdSynthToken = _usdSynthToken;
        price = _price;
        ethSynthToken = _ethSynthToken;
        beyondExchange = _beyondExchange;

    }
    
    function createLoan(uint256 _value, address _beneficiary) onlyContract external returns(uint256){
        
        uint256 loanFee = (_value.mul(loanFeeRatio)).div(100);
        uint256 valueAfterLoanFee = _value.sub(loanFee);
        uint256 loanCollatteral = (_value.mul(loanCollatteralRatio)).div(100);
        uint256 amountToLoan = _value.sub(loanCollatteral);
        
        loanDetails[_beneficiary].collatteralETHb = loanDetails[_beneficiary].collatteralETHb.add(loanCollatteral);
        loanDetails[_beneficiary].loanValueETHb = loanDetails[_beneficiary].loanValueETHb.add(amountToLoan);
        loanDetails[_beneficiary].totalValueAfterLoanFeeETHb = loanDetails[_beneficiary].totalValueAfterLoanFeeETHb.add(valueAfterLoanFee);
        loanDetails[_beneficiary].loansOfETHb = loanDetails[_beneficiary].loansOfETHb.add(1);
        
        totalETHb = totalETHb.add( amountToLoan);
        
        ethSynthToken.mint(amountToLoan,_beneficiary);
        
        openLoans = openLoans.add(1);
        
        return loanFee;
    }
    
    function createLoanUSDb(uint256 _value, address _beneficiary) onlyContract external returns(uint256){
        
        uint256 loanFee = (_value.mul(loanFeeRatio)).div(100);
        uint256 valueAfterLoanFee = _value.sub(loanFee);
        uint256 loanCollatteral = (_value.mul(loanCollatteralRatio)).div(100);
        uint256 amountToLoan = _value.sub(loanCollatteral);
        
        loanDetails[_beneficiary].collatteralUSDb = loanDetails[_beneficiary].collatteralUSDb.add(loanCollatteral);
        loanDetails[_beneficiary].totalValueAfterLoanFeeUSDb = loanDetails[_beneficiary].totalValueAfterLoanFeeUSDb.add(valueAfterLoanFee);
        loanDetails[_beneficiary].loansOfUSDb = loanDetails[_beneficiary].loansOfUSDb.add(1);
        
        
        string memory _synth= "ETHb";
        bytes32 __synth = stringToBytes32(_synth);
        uint256 __synthRate = uint256(price.getLatestPrice(__synth)).mul(10000000000);
        uint256 __synthAmountToUsd = (amountToLoan.mul(__synthRate)).div(1 ether);
        
        totalUSDb = totalUSDb.add(__synthAmountToUsd);
        
        loanDetails[_beneficiary].loanValueUSDb = loanDetails[_beneficiary].loanValueUSDb.add(__synthAmountToUsd);
        
        usdSynthToken.mint(__synthAmountToUsd,_beneficiary);
        
        openLoans = openLoans.add(1);
        
        return loanFee;
    }
    
    function closeLoan(address _beneficiary) onlyContract external returns(uint256){
        
        require (ethSynthToken.balanceCheck(_beneficiary) >= loanDetails[_beneficiary].loanValueETHb, "insufficient ETHb balance" );
        
        require (loanDetails[_beneficiary].loanValueETHb > 0,"You dont have a loan");
        
        ethSynthToken.burn(loanDetails[_beneficiary].loanValueETHb,_beneficiary);
        
        uint256 _value = loanDetails[_beneficiary].totalValueAfterLoanFeeETHb;
        totalETHb = totalETHb.sub(loanDetails[_beneficiary].loanValueETHb);
        
        loanDetails[_beneficiary].loanValueETHb = loanDetails[_beneficiary].loanValueETHb.sub(loanDetails[_beneficiary].loanValueETHb);
        loanDetails[_beneficiary].collatteralETHb = loanDetails[_beneficiary].collatteralETHb.sub(loanDetails[_beneficiary].collatteralETHb);
        loanDetails[_beneficiary].totalValueAfterLoanFeeETHb = loanDetails[_beneficiary].totalValueAfterLoanFeeETHb.sub(loanDetails[_beneficiary].totalValueAfterLoanFeeETHb);
        openLoans = openLoans.sub(loanDetails[_beneficiary].loansOfETHb);
        loanDetails[_beneficiary].loansOfETHb = loanDetails[_beneficiary].loansOfETHb.sub(loanDetails[_beneficiary].loansOfETHb);
        
        return _value;
    }
    
    function closeLoanUSDb(address _beneficiary) onlyContract external returns(uint256){

        require (usdSynthToken.balanceCheck(_beneficiary) >= loanDetails[_beneficiary].loanValueUSDb, "insufficient ETHb balance" );
        
        require (loanDetails[_beneficiary].loanValueUSDb > 0,"You dont have a loan");
    
        usdSynthToken.burn(loanDetails[_beneficiary].loanValueUSDb,_beneficiary);
        
        uint256 _value = loanDetails[_beneficiary].totalValueAfterLoanFeeUSDb;
        totalUSDb = totalUSDb.sub(loanDetails[_beneficiary].loanValueUSDb);
        
        loanDetails[_beneficiary].loanValueUSDb = loanDetails[_beneficiary].loanValueUSDb.sub(loanDetails[_beneficiary].loanValueUSDb);
        loanDetails[_beneficiary].collatteralUSDb = loanDetails[_beneficiary].collatteralUSDb.sub(loanDetails[_beneficiary].collatteralUSDb);
        loanDetails[_beneficiary].totalValueAfterLoanFeeUSDb = loanDetails[_beneficiary].totalValueAfterLoanFeeUSDb.sub(loanDetails[_beneficiary].totalValueAfterLoanFeeUSDb);
        openLoans = openLoans.sub(loanDetails[_beneficiary].loansOfUSDb);
        loanDetails[_beneficiary].loansOfUSDb = loanDetails[_beneficiary].loansOfUSDb.sub(loanDetails[_beneficiary].loansOfUSDb);
        
        return _value;
    }
    
    function setLoanFeeRation(uint256 _fee) external onlyContract{
        loanFeeRatio = _fee;
    }
    
    function setLoanCollatteralRatio(uint256 _collatteralRatio) external onlyContract{
        loanCollatteralRatio = _collatteralRatio;
    }
    
    function setBeyondExchangeAddress(address _address) external onlyContract{
        beyondExchange = _address;
    }
    
    function viewLoanDetails(address _address) external view returns
    (
        uint256 _collatteralETHb,
        uint256 _loanValueETHb,
        uint256 _totalValueAfterLoanFeeETHb,
        uint256 _loansOfETHb,
        uint256 _collatteralUSDb,
        uint256 _loanValueUSDb,
        uint256 _totalValueAfterLoanFeeUSDb,
        uint256 _loansOfUSDb
    ) 
    {
        _collatteralETHb = loanDetails[_address].collatteralETHb;
        _loanValueETHb = loanDetails[_address].loanValueETHb; 
        _totalValueAfterLoanFeeETHb = loanDetails[_address].totalValueAfterLoanFeeETHb;
        _loansOfETHb = loanDetails[_address].loansOfETHb;
        _collatteralUSDb = loanDetails[_address].collatteralUSDb;
        _loanValueUSDb = loanDetails[_address].loanValueUSDb;
        _totalValueAfterLoanFeeUSDb = loanDetails[_address].totalValueAfterLoanFeeUSDb;
        _loansOfUSDb = loanDetails[_address].loansOfUSDb;
    }
    
    function viewLoanConatractDetails() external view returns
    (
        uint256 _loanFeeRatio,
        uint256 _loanCollatteralRatio,
        uint256 _totalETHb,
        uint256 _totalUSDb,
        uint256 _openLoans
    )
    {
        _loanFeeRatio = loanFeeRatio;
        _loanCollatteralRatio = loanCollatteralRatio;
        _totalETHb = totalETHb;
        _totalUSDb = totalUSDb;
        _openLoans = openLoans;
    }
    
    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
    
        assembly {
            result := mload(add(source, 32))
        }
        
    }
    
}