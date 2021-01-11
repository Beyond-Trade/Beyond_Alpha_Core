pragma solidity ^0.5.16;

import './StandardToken.sol';
import './Ownable.sol';

contract BTCb is StandardToken, Ownable
{
    
    string public constant name = "Beyond BTC";
    string public constant symbol = "BTCb";
    uint8 public constant decimals = 18;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    constructor() public Ownable(msg.sender){ //address payable _wallet ,uint256 _ethPrice

        _totalSupply = 0;

    }

    function mint(uint256 _value, address _beneficiary) external returns (bool){

        require(_value > 0);
        balances[_beneficiary] = balances[_beneficiary].add(_value);
        _totalSupply = _totalSupply.add(_value);
        
        emit Transfer(address(this),_beneficiary, _value);
        
    }

    function saleTransfer(address _to, uint256 _value) internal returns (bool) {
        
        return super.transfer(_to, _value);

    }
    
    function balanceCheck(address _beneficiary) public view returns(uint256){
        require(_beneficiary != address(0));
        return super.balanceOf(_beneficiary);
    }
    
    function burn(uint256 _value, address _beneficiary) external {
        require(balanceCheck(_beneficiary) >= _value,"User does not have sufficient synths to burn");
        _totalSupply = _totalSupply.sub(_value);
        balances[_beneficiary] = balances[_beneficiary].sub(_value);
        
        emit Transfer(address(this),_beneficiary, _value);
    }
}