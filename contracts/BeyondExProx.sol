pragma solidity ^0.5.16;

import './SafeMath.sol';
import './Ownable.sol';

interface IUSDSynth {
    function mint(uint256 _value, address _beneficiary) external returns (bool);
    function balanceCheck(address _beneficiary) external view returns(uint256);
    function burn(uint256 _value, address _beneficiary) external;
}

interface ISynth {
    function mint(uint256 _value, address _beneficiary) external returns (bool);
    function balanceCheck(address _beneficiary) external view returns(uint256);
    function burn(uint256 _value, address _beneficiary) external;
}

interface IPriceConsumerV3{
    function getLatestPrice(bytes32 _synth) external returns (int);
}

interface IBeyond {
    function balanceCheck(address _beneficiary) external view returns(uint256);
    function staking(address _beneficiary, address _contract, uint256 _value) external;
    function unStaking(address _beneficiary, address _contract, uint256 _value) external;
    function tokenValue() external view returns(uint256);
    // function rewardTransfer(uint256 _value,address _beneficiary) external;
}

interface IReward {
    function initialize() external;
    function collectRewardFromReward(uint256 beyondTokenValue, uint256 bUSDValue, uint256 totalMintedUSDb, uint256 collatteralValue) external returns (uint256 reward, uint256 _rewardClaimTime, uint256 currentCycleReward, uint256 _currentTime);
    function getRewardClaimTime() external view returns(uint256);
    function updateReward(uint256 _fee) external;
    function userRewardDetailsFromReward(uint256 _time, uint256 bUSDValue, uint256 totalMintedUSDb,uint256 collatteralValue,uint256 beyondTokenValue) external view returns(uint256 reward);
    function getRewardContractDetails() external view returns(uint256 _currentTime, uint256 _APY);
    function setAPY(uint256 _APY) external;
    function claimRewardFromReward(address _beneficiary, uint256 investTime, uint256 _reward) external;
    function checkEarlyRedemptionFee(uint256 investTime, uint256 _reward) external view returns(uint256 earlyRedemptionFee);
}

contract beyondExProx is Ownable{
    
    using SafeMath for uint256;
    
    IPriceConsumerV3 public price;
    IUSDSynth public usdSynthToken;
    ISynth public synthToken;
    IBeyond public beyond;
    IReward public rewardContract;
    
    uint256 public beyondTokenValueInDollar;
    uint256 public collatteralRatio = 300;//300% Collatteral Ratio

    uint256 public tradeFeeRatio = 300000000000000000; //0.3%
    uint256 public totalMintedUSDb = 0;
    uint256 public totalStackedBYN = 0;

    
    address public beyondExchange;
    
    bool public start;
    
    mapping (bytes32 => Synth) public getSynthAddress;
    mapping (address => CollatteralOfUser) public collatteral;

    
    struct Synth{
        bytes32 _synth;
        ISynth _contractAddress;
    }
    
    struct CollatteralOfUser{
        uint256 bUSDValue;
        uint256 USDbValueinBYN;
        uint256 collatteralValue;
        uint256 currentCollatteralRatio;
        uint256 rewardClaimTime;
        uint256 totalReward;
        uint256 investTime;
        //mapping (uint256 => rewardOfUser) rewardOfUserTrack;
    }
    
    // struct rewardOfUser{
    //     uint256 cycleReward;
    // }
    
    modifier onlyContract{
        require(msg.sender == beyondExchange,"Not Authorized address");
        _;
    }
    
    constructor( IUSDSynth _usdSynthToken, IPriceConsumerV3 _price, IBeyond _beyond, address _beyondExchange, IReward _rewardContract) public Ownable(msg.sender){
        
        usdSynthToken = _usdSynthToken;
        price = _price;
        beyond = _beyond;
        beyondExchange = _beyondExchange;
        rewardContract = _rewardContract;
    }
    
    function startExchangeProx() external onlyContract{
        start = true;
        rewardContract.initialize();
    }

    function mintUSDSynth(uint256 _value, address _minter) onlyContract external {
        
        require (start == true,"Exchange not started");
        
        uint256 amountInBYN = (_value.mul(1 ether)).div(getBeyondTokenValue());
        uint256 collatteralValueInBYN = (amountInBYN.mul((collatteralRatio.mul(1 ether)).div(100))).div(1 ether);
        
        collatteral[_minter].bUSDValue = collatteral[_minter].bUSDValue.add(_value);
        collatteral[_minter].USDbValueinBYN = collatteral[_minter].USDbValueinBYN.add(amountInBYN);
        collatteral[_minter].collatteralValue = collatteral[_minter].collatteralValue.add(collatteralValueInBYN);
        collatteral[_minter].currentCollatteralRatio =(collatteral[_minter].collatteralValue.mul(100)).div(collatteral[_minter].USDbValueinBYN);
        collatteral[_minter].rewardClaimTime = rewardContract.getRewardClaimTime();
        
        if(collatteral[_minter].investTime == 0){
            collatteral[_minter].investTime = uint256(now);
        }
        
        require(collatteralValueInBYN <= beyond.balanceCheck(_minter));
        
        totalMintedUSDb = totalMintedUSDb.add(_value);
        totalStackedBYN = totalStackedBYN.add(collatteralValueInBYN);
        
        usdSynthToken.mint(_value,_minter);
        beyond.staking(_minter,beyondExchange,collatteralValueInBYN);
        
        
    }
    
    function mintSynth(string calldata _synth,address _address,uint256 _value) onlyContract external {
        
        //require (start == true,"Exchange not started");
        
        require(usdSynthToken.balanceCheck(_address) > 0,"");
        
        bytes32 __synth = stringToBytes32(_synth);
        
        require(usdSynthToken.balanceCheck(_address) >= _value,"insufficient balance of USDb");
        
        uint256 fee = ((_value.mul(tradeFeeRatio)).div(100)).div(1 ether);
        uint256 SynthToMint = _value.sub(fee);
        
        rewardContract.updateReward(fee);
        
        SynthToMint = (SynthToMint.mul(1 ether)).div((uint256(price.getLatestPrice(__synth))).mul(10000000000));
        synthToken = getSynthAddress[__synth]._contractAddress;
        
        usdSynthToken.burn(_value,_address);
        
        synthToken.mint(SynthToMint,_address);
        
    }
   
    function convertSynths(string calldata _synth1, string calldata _synth2,address _beneficiary, uint256 _value) onlyContract external {
        
        //require (start == true,"Exchange not started");
        
        bytes32 __synth1 = stringToBytes32(_synth1);
        bytes32 __synth2 = stringToBytes32(_synth2);
        
        synthToken = getSynthAddress[__synth1]._contractAddress;
        uint256 __synth1Amount = synthToken.balanceCheck(_beneficiary);
        
        require (_value <= __synth1Amount,"insufficient balance");
        
        uint256 __synth1Rate = uint256(price.getLatestPrice(__synth1)).mul(10000000000);
        uint256 __synth1AmountToUsd = (_value.mul(__synth1Rate)).div(1 ether);
        uint256 fee = ((__synth1AmountToUsd.mul(tradeFeeRatio)).div(100)).div(1 ether);
        uint256 __synth2Amount = __synth1AmountToUsd.sub(fee);
       
        rewardContract.updateReward(fee);
        
        synthToken.burn(_value,_beneficiary);
        
        synthToken = getSynthAddress[__synth2]._contractAddress;
        uint256 __synth2Rate = uint256(price.getLatestPrice(__synth2)).mul(10000000000);
        
        __synth2Amount = (__synth2Amount.mul(1 ether)).div(__synth2Rate);
        
        synthToken.mint(__synth2Amount,_beneficiary);
        
    }
    
    function synthToUSD (string calldata _synth, address _beneficiary, uint256 _value) onlyContract external {

        //require (start == true,"Exchange not started");

        bytes32 __synth1 = stringToBytes32(_synth);
        
        synthToken = getSynthAddress[__synth1]._contractAddress;
        uint256 __synth1Amount = synthToken.balanceCheck(_beneficiary);
        
        require (_value <= __synth1Amount,"insufficient balance");
        
        uint256 __synth1Rate = uint256(price.getLatestPrice(__synth1)).mul(10000000000);
        uint256 __synth1AmountToUsd = (_value.mul(__synth1Rate)).div(1 ether);
        uint256 fee = ((__synth1AmountToUsd.mul(tradeFeeRatio)).div(100)).div(1 ether);
       
        __synth1AmountToUsd = __synth1AmountToUsd.sub(fee);
        
        rewardContract.updateReward(fee);
 
        synthToken.burn(_value,_beneficiary);
        
        usdSynthToken.mint(__synth1AmountToUsd,_beneficiary);
        
    }
    
    function setSynthAddress(string calldata _synth, ISynth synthAddress) external onlyContract {
        
        bytes32 __synth = stringToBytes32(_synth); 
        getSynthAddress[__synth]._synth = __synth;
        getSynthAddress[__synth]._contractAddress = synthAddress;
        
    }
    
    function burnUSDbToSettleCollatteralRatio(address _beneficiary) onlyContract external /*returns(uint256)*/{
        
        //require (start == true,"Exchange not started");
        
        uint256 bUSDAmountInBYN;
        uint256 collatteralValueInBYN;
        uint256 additionalBYNValueForCollateral;
        uint256 additionalCollatteralValueInUSDb;
        uint256 collatteralRatioUpdated;

        getBeyondTokenValue();
        
        (bUSDAmountInBYN, collatteralValueInBYN, additionalBYNValueForCollateral, additionalCollatteralValueInUSDb, collatteralRatioUpdated) = checkUserCollatteral(_beneficiary);
        
        require (collatteralValueInBYN > collatteral[_beneficiary].collatteralValue,"No need to burn USD");
        
        require (additionalCollatteralValueInUSDb <= usdSynthToken.balanceCheck(_beneficiary),"");
           
        collatteral[_beneficiary].bUSDValue = collatteral[_beneficiary].bUSDValue.sub(additionalCollatteralValueInUSDb);
        usdSynthToken.burn(additionalCollatteralValueInUSDb,_beneficiary);
     
        totalMintedUSDb = totalMintedUSDb.sub(additionalCollatteralValueInUSDb);
        
        //return collatteralRatioUpdated;
        
    }

    function checkUserCollatteral(address _beneficiary) public view returns (uint256 bUSDAmountInBYN, uint256 collatteralValueInBYN, uint256 additionalBYNValueForCollateral, uint256 additionalCollatteralValueInUSDb, uint256 collatteralRatioUpdated){
        
        bUSDAmountInBYN = (collatteral[_beneficiary].bUSDValue.mul(1 ether)).div(beyondTokenValueInDollar);
        collatteralValueInBYN = (bUSDAmountInBYN.mul((collatteralRatio.mul(1 ether)).div(100))).div(1 ether);
    
        
        if (collatteralValueInBYN > collatteral[_beneficiary].collatteralValue){
            additionalBYNValueForCollateral = collatteralValueInBYN.sub(collatteral[_beneficiary].collatteralValue);
            additionalCollatteralValueInUSDb = ((additionalBYNValueForCollateral.div(collatteralRatio.div(100))).mul(beyondTokenValueInDollar)).div(1 ether);
            collatteralRatioUpdated = (collatteral[_beneficiary].collatteralValue.mul(100)).div(bUSDAmountInBYN);
        }
        else if (collatteralValueInBYN < collatteral[_beneficiary].collatteralValue){
            additionalBYNValueForCollateral = collatteral[_beneficiary].collatteralValue.sub(collatteralValueInBYN);
            additionalCollatteralValueInUSDb = 0;
            collatteralRatioUpdated = (collatteral[_beneficiary].collatteralValue.mul(100)).div(bUSDAmountInBYN);
        }
        else if (collatteralValueInBYN == collatteral[_beneficiary].collatteralValue){
            additionalBYNValueForCollateral = 0;
            additionalCollatteralValueInUSDb = 0;
            collatteralRatioUpdated = (collatteral[_beneficiary].collatteralValue.mul(100)).div(bUSDAmountInBYN);
        }
    }
    
    function burnUSDbToReleaseCollateral (address _beneficiary, uint256 _value) onlyContract external /*returns(uint256)*/{
        
        //require (start == true,"Exchange not started");
        
        uint256 collatteralRatioUpdated;

        getBeyondTokenValue();
        
        (, , , , collatteralRatioUpdated) = checkUserCollatteral(_beneficiary);
        
        uint256 amountInBYN = (_value.mul(1 ether)).div(getBeyondTokenValue());
        uint256 collatteralValueInBYN = (amountInBYN.mul((collatteralRatio.mul(1 ether)).div(100))).div(1 ether);
        
        require (collatteralRatioUpdated >= collatteral[_beneficiary].currentCollatteralRatio,"settle your collatterla ratio first");
        
        require (usdSynthToken.balanceCheck(_beneficiary) >= _value,"insufficient USDb amount to return");
        
        require (collatteral[_beneficiary].bUSDValue >= _value,"insufficient USDb amount minted");
        
        usdSynthToken.burn(_value,_beneficiary);
        
        beyond.unStaking(_beneficiary,beyondExchange,collatteralValueInBYN);
        
        collatteral[_beneficiary].bUSDValue = collatteral[_beneficiary].bUSDValue.sub(_value);
        collatteral[_beneficiary].USDbValueinBYN = collatteral[_beneficiary].USDbValueinBYN.sub(amountInBYN);
        collatteral[_beneficiary].collatteralValue = collatteral[_beneficiary].collatteralValue.sub(collatteralValueInBYN);
        
        if (collatteral[_beneficiary].bUSDValue == 0 && collatteral[_beneficiary].collatteralValue > 0){
            
            beyond.unStaking(_beneficiary,beyondExchange,collatteral[_beneficiary].collatteralValue);
            collatteral[_beneficiary].USDbValueinBYN = collatteral[_beneficiary].USDbValueinBYN.sub(collatteral[_beneficiary].USDbValueinBYN);
            collatteral[_beneficiary].collatteralValue = collatteral[_beneficiary].collatteralValue.sub(collatteral[_beneficiary].collatteralValue);
            
        }
        
        if (collatteral[_beneficiary].bUSDValue == 0){
            collatteral[_beneficiary].currentCollatteralRatio = collatteral[_beneficiary].currentCollatteralRatio.sub(collatteral[_beneficiary].currentCollatteralRatio);
        }
    
        totalMintedUSDb = totalMintedUSDb.sub(collatteral[_beneficiary].bUSDValue);
        totalStackedBYN = totalStackedBYN.sub(collatteral[_beneficiary].collatteralValue);
        
        //return collatteralRatioUpdated;
    }
    
    function collectReward(address _beneficiary) onlyContract external{
        
        //require (start == true,"Exchange not started");
        
        require (uint256(now) > collatteral[_beneficiary].rewardClaimTime,"time cycle is not completed");
        
        require (collatteral[_beneficiary].bUSDValue > 0,"No minted sUSD's");
        
        uint256 reward;
        uint256 _rewardClaimTime;
        uint256 currentCycleReward;
        uint256 currentTime;
        
        (reward, _rewardClaimTime, currentCycleReward, currentTime) = rewardContract.collectRewardFromReward(getBeyondTokenValue(),collatteral[_beneficiary].bUSDValue,totalMintedUSDb,collatteral[_beneficiary].collatteralValue);
        
        // if (currentCycleReward > 0){
        
        //     collatteral[_beneficiary].rewardOfUserTrack[currentTime].cycleReward = reward;
            
            
        // }
        collatteral[_beneficiary].totalReward = collatteral[_beneficiary].totalReward.add(reward);
        collatteral[_beneficiary].rewardClaimTime = _rewardClaimTime;
    }
    
    function claimReward(address _beneficiary) onlyContract external{
        
        //require (start == true,"Exchange not started");
        
        require (collatteral[_beneficiary].totalReward > 0,"No reward available");
        
        rewardContract.claimRewardFromReward(_beneficiary,collatteral[_beneficiary].investTime,collatteral[_beneficiary].totalReward);
        
        collatteral[_beneficiary].totalReward = collatteral[_beneficiary].totalReward.sub(collatteral[_beneficiary].totalReward);
        
    }
    
    function userRewardDetails(address _beneficiary, uint256 _time) external view returns(uint256 reward, uint256 collectableReward, uint256 earlyRedemptionFee, uint256 investTime){
        reward = rewardContract.userRewardDetailsFromReward(_time,collatteral[_beneficiary].bUSDValue,totalMintedUSDb,collatteral[_beneficiary].collatteralValue,beyondTokenValueInDollar);
        earlyRedemptionFee = rewardContract.checkEarlyRedemptionFee(collatteral[_beneficiary].investTime, collatteral[_beneficiary].totalReward);
        collectableReward = collatteral[_beneficiary].totalReward;
        investTime = collatteral[_beneficiary].investTime;
    }
    
    function getBeyondTokenValue() public returns (uint256){
        
        string memory _synth= "ETHb";
        bytes32 __synth = stringToBytes32(_synth);
        uint256 tokenValue =  (beyond.tokenValue()).mul(1 ether);
        beyondTokenValueInDollar = ((uint256(price.getLatestPrice(__synth)).mul(1 ether)).div(tokenValue)).mul(10000000000);
        return beyondTokenValueInDollar;
        
    }
    
    // function setBeyondExchangeAddress(address _address) external onlyContract{
    //     beyondExchange = _address;
    // }
    
    function getBYN(address _beneficiary) external view returns(uint256 unstackedBYN, uint256 stackedBYN, uint256 totalBYN){
       
        unstackedBYN = beyond.balanceCheck(_beneficiary);
        stackedBYN = collatteral[_beneficiary].collatteralValue;
        totalBYN = unstackedBYN.add(stackedBYN);
        
    }
    
    function getExchangeDetails() external view returns(uint256 _currentTime, uint256 _collatteralRatio, uint256 _APY, uint256 _tradeFee){ 
        
        (_currentTime, _APY) = rewardContract.getRewardContractDetails();
        _collatteralRatio = collatteralRatio;
        _tradeFee = tradeFeeRatio;
    }
    
    function getCollateralDetails(address _beneficiary) external view returns (uint256 _bUSDValue, uint256 _USDbValueinBYN, uint256 _collatteralValue, uint256 _currentCollatteralRatio){
        _bUSDValue = collatteral[_beneficiary].bUSDValue;
        _USDbValueinBYN = collatteral[_beneficiary].USDbValueinBYN;
        _collatteralValue = collatteral[_beneficiary].collatteralValue;
        _currentCollatteralRatio = collatteral[_beneficiary].currentCollatteralRatio;
    }
    
    function setCollatteralRatio(uint256 _ratio) external onlyContract{
        collatteralRatio = _ratio;
    }
    
    function setTradeFeeAndAPY(uint256 _fee, uint256 _APY) external onlyContract{
        tradeFeeRatio = _fee;
        rewardContract.setAPY(_APY);
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