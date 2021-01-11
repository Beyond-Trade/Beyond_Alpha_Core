pragma solidity ^0.5.16;

import './StandardToken.sol';
import './Ownable.sol';
import './Pausable.sol';


contract Beyond is StandardToken, Ownable, Pausable
{
    
    string public constant name = "Beyond";
    string public constant symbol = "BYN";
    uint8 public constant decimals = 18;
        
    uint256 public totalReleased;
    uint256 ethPrice; //rate: how many tokens to send against recieved value
    uint256 public weiRaised;// Amount of wei raised
  
    address payable wallet;// Address where funds are collected
    address public exchangeContract;
    address public rewardContract;
    
    bool public fundraising;

    mapping (address => Investor) public investorInfoByAddress;
    
    event Transfer(address indexed from, address indexed to, uint256 value);

    struct Investor{ 
        address investorAddress;
        uint256 investorTotalBalance;
        uint256 addTime;
        uint256 id;
    }
    
    modifier onlyContract{
        require(msg.sender == rewardContract || msg.sender == exchangeContract,"Not Authorized address");
        _;
    }
    
    constructor(address payable _wallet ,uint256 _ethPrice) public Ownable(msg.sender){ 

        totalReleased = 0;
        _totalSupply = 0;
        wallet = _wallet;
        ethPrice = _ethPrice;

    }

    function buyTokens() public payable {
  
        uint256 weiAmount = msg.value;
        address _beneficiary = msg.sender;
    
        require(weiAmount > 0, "Value is not greater than zero");
    
        require(ethPrice > 0, "EthPrice is zero");
  
        uint256 tokens = (weiAmount.mul(ethPrice));
    
        weiRaised = weiRaised.add(weiAmount);
    
        investorInfoByAddress[_beneficiary].investorTotalBalance = investorInfoByAddress[_beneficiary].investorTotalBalance.add(tokens);
    
        mint(tokens,msg.sender);
        
        wallet.transfer(msg.value);
        
    }

    function balanceCheck(address _beneficiary) public view returns(uint256){
        require(_beneficiary != address(0));
        return super.balanceOf(_beneficiary);
    }
    
    function mint(uint256 _value, address _beneficiary) internal returns (bool){

        require(_value > 0);
        balances[_beneficiary] = balances[_beneficiary].add(_value);
        _totalSupply = _totalSupply.add(_value);
        
        emit Transfer(address(this),_beneficiary, _value);

    }
    
    function burn(uint256 _value, address _beneficiary) internal {
        require(balanceCheck(_beneficiary) >= _value,"User does not have sufficient synths to burn");
        _totalSupply = _totalSupply.sub(_value);
        balances[_beneficiary] = balances[_beneficiary].sub(_value);
        
        emit Transfer(address(this),_beneficiary, _value);
    }
    
    function tokenValue() external view returns(uint256){
        return ethPrice;
    }
    
    function rewardTransfer(uint256 _value,address _beneficiary) onlyContract external{
        // balances[_contract] = balances[_contract].sub(_value);
        balances[_beneficiary] = balances[_beneficiary].add(_value);
        _totalSupply = _totalSupply.add(_value);
        
        emit Transfer(address(this),_beneficiary, _value);
    }
    
    function staking(address _beneficiary, address _contract, uint256 _value) onlyContract external {
        balances[_beneficiary] = balances[_beneficiary].sub(_value);
        balances[_contract] = balances[_contract].add(_value);
        emit Transfer(_beneficiary,_contract, _value);
    }
    
    function unStaking(address _beneficiary, address _contract, uint256 _value) onlyContract external {
        balances[_contract] = balances[_contract].sub(_value);
        balances[_beneficiary] = balances[_beneficiary].add(_value);
        emit Transfer(_beneficiary,_contract, _value);
    }
    
    function calculateTokenAmount(uint256 _value) public view returns(uint256){
        return ((_value.mul(ethPrice)).mul(1 ether));
    }
    
    function setBeyondExchangeAddressProx(address _address) public onlyOwner{
        exchangeContract = _address;
    }
    
    function setRewardContract(address _address) public onlyOwner{
        rewardContract = _address;
    }
     
}
