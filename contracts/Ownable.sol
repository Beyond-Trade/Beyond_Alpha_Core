pragma solidity ^0.5.16;


contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  
  constructor (address _owner) public {
    owner = _owner;
  }

  
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}