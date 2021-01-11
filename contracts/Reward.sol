pragma solidity ^0.5.16;

import './Ownable.sol';
import './SafeMath.sol';

interface IBeyond {
     function rewardTransfer(uint256 _value,address _beneficiary) external;
}

contract Reward is Ownable{
    
    using SafeMath for uint256;
    
    IBeyond public beyond;
    
    uint256 public rewardClaimTime;
    uint256 public currentTime;
    uint256 public interval = 5 minutes;
    uint256 public APY = 20; //20%
    
    address public beyondExProx;
    
    
    mapping (uint256 => rewardCycle) public rewardCycleDetail;
    
    modifier onlyContract{
        require(msg.sender == beyondExProx,"Not Authorized address");
        _;
    }
    
    struct rewardCycle{
        uint256 currentCycleReward;
        uint256 previousCycleReward;
        uint256 cycleRewardRemaining;
    }
    
    constructor( 
        
        IBeyond _beyond
        
    ) public Ownable(msg.sender){
        
        beyond = _beyond;
    }
    
    function initialize() public{
        
        currentTime = uint256(now);
        rewardCycleDetail[uint256(now)].currentCycleReward = 0;
        rewardCycleDetail[uint256(now)].previousCycleReward = 0;
        rewardCycleDetail[uint256(now)].cycleRewardRemaining = 0;
        rewardClaimTime = uint256(now).add(interval);
    }
    
    function checkUserReward(
    
        uint256 beyondTokenValue,
        uint256 bUSDValue,
        uint256 totalMintedUSDb,
        uint256 collatteralValue
        
    ) public view returns(
    
        uint256 reward,
        uint256 tradeReward
        
    ) {
        
        uint256 rewardRatio = (bUSDValue.mul(100)).div(totalMintedUSDb);
        tradeReward = (rewardCycleDetail[currentTime.sub(interval)].currentCycleReward.mul(rewardRatio)).div(100);
        uint256 rewardInBYN = (tradeReward.mul(1 ether)).div(beyondTokenValue);
        uint256 APYReward = ((collatteralValue.mul(APY)).div(100)).div(365);
        reward = rewardInBYN.add(APYReward);
    }
    
    function collectRewardFromReward(
    
        uint256 beyondTokenValue, 
        uint256 bUSDValue, 
        uint256 totalMintedUSDb, 
        uint256 collatteralValue
        
    ) external onlyContract returns (
    
        uint256 reward,
        uint256 _rewardClaimTime,
        uint256 currentCycleReward,
        uint256 _currentTime
        
    ){
        
        if (uint256(now) > rewardClaimTime){
            
            rewardCycleDetail[currentTime].cycleRewardRemaining = rewardCycleDetail[currentTime].cycleRewardRemaining.add(rewardCycleDetail[currentTime.sub(interval)].cycleRewardRemaining);
            rewardCycleDetail[currentTime].currentCycleReward = rewardCycleDetail[currentTime].currentCycleReward.add(rewardCycleDetail[currentTime.sub(interval)].cycleRewardRemaining);
            rewardCycleDetail[currentTime].previousCycleReward = rewardCycleDetail[currentTime].previousCycleReward.add(rewardCycleDetail[currentTime.sub(interval)].cycleRewardRemaining);
            rewardClaimTime = rewardClaimTime.add(interval);
            currentTime = currentTime.add(interval);
        }
        
        uint256 tradeReward;
        (reward,tradeReward) = checkUserReward(beyondTokenValue,bUSDValue,totalMintedUSDb,collatteralValue);
        
        if (rewardCycleDetail[currentTime.sub(interval)].currentCycleReward > 0){
            
            rewardCycleDetail[currentTime.sub(interval)].cycleRewardRemaining = rewardCycleDetail[currentTime.sub(interval)].cycleRewardRemaining.sub(tradeReward);
            
        }
        currentCycleReward = rewardCycleDetail[currentTime.sub(interval)].currentCycleReward;
        _rewardClaimTime = rewardClaimTime;
        _currentTime = currentTime.sub(interval);
    }

    function claimRewardFromReward(
    
        address _beneficiary, 
        uint256 investTime, 
        uint256 _reward
        
    ) onlyContract external{
        
        uint256 _days = 4;
        uint256 one = 1;
        
        if (investTime.add(1200) < uint256(now)){
            beyond.rewardTransfer(_reward,_beneficiary);
        }
        else if(investTime.add(1200) > uint256(now)){
            uint256 remianingDays = ((investTime.add(1200)).sub(uint256(now))).div(300);
            uint256 rewardDaysKept = (_days).sub(remianingDays);
            uint256 earlyRedemptionFee = (((one.mul(1 ether)).sub((rewardDaysKept.mul(1 ether)).div(4))).mul(_reward)).div(1 ether);
            uint256 reward = _reward.sub(earlyRedemptionFee);
            beyond.rewardTransfer(reward,_beneficiary);
        }
    }
    
    function checkEarlyRedemptionFee(
    
        //address _beneficiary, 
        uint256 investTime, 
        uint256 _reward
        
    ) external view returns(uint256 earlyRedemptionFee){
        
        uint256 _days = 4;
        uint256 one = 1;
        
        if (investTime.add(1200) < uint256(now)){
            earlyRedemptionFee = 0;
            //beyond.rewardTransfer(_reward,_beneficiary);
        }
        else if(investTime.add(1200) > uint256(now)){
            uint256 remianingDays = ((investTime.add(1200)).sub(uint256(now))).div(300);
            uint256 rewardDaysKept = (_days).sub(remianingDays);
            earlyRedemptionFee = (((one.mul(1 ether)).sub((rewardDaysKept.mul(1 ether)).div(4))).mul(_reward)).div(1 ether);
            //uint256 reward = _reward.sub(earlyRedemptionFee);
            //beyond.rewardTransfer(reward,_beneficiary);
        }
    }
    
    function userRewardDetailsFromReward(
    
        uint256 _time,
        uint256 bUSDValue,
        uint256 totalMintedUSDb,
        uint256 collatteralValue,
        uint256 beyondTokenValue
        
    ) external view returns(
    
        uint256 _reward
        
    ){
        
        uint256 rewardRatio = (bUSDValue.mul(100)).div(totalMintedUSDb);
        uint256 tradeReward = (rewardCycleDetail[_time].currentCycleReward.mul(rewardRatio)).div(100);
        uint256 rewardInBYN = (tradeReward.mul(1 ether)).div(beyondTokenValue);
        uint256 APYReward = ((collatteralValue.mul(APY)).div(100)).div(365);
        _reward = rewardInBYN.add(APYReward);
        
        // uint256 rewardRatio = (bUSDValue.mul(100)).div(totalMintedUSDb);
        // _reward = (rewardCycleDetail[_time].currentCycleReward.mul(rewardRatio)).div(100);
        
    }
    
    function getRewardClaimTime() external view returns(uint256){
        return rewardClaimTime;
    }
    
    function updateReward(
    
        uint256 _fee
        
    ) onlyContract external {
        
        rewardCycleDetail[currentTime].currentCycleReward =  rewardCycleDetail[currentTime].currentCycleReward.add(_fee);
        rewardCycleDetail[currentTime].cycleRewardRemaining =  rewardCycleDetail[currentTime].cycleRewardRemaining.add(_fee);
    }
    
    function getRewardContractDetails() external view returns(uint256 _currentTime, uint256 _APY){
        
        _currentTime = currentTime;
        _APY = APY;
    }
    
    function setAPY(
    
        uint256 _APY
        
    ) onlyContract external {
        
        APY = _APY;
    }
    
    function setExchangeProxAddress(address _address) public onlyOwner{
        beyondExProx = _address;   
    }
}