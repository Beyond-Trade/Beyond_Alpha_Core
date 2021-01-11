pragma solidity ^0.5.16;

import './Ownable.sol';
import './SafeMath.sol';

interface IBeyondExProx {
    function mintUSDSynth(uint256 _value, address _minter) external;
    function mintSynth(string calldata _synth,address _address, uint256 _value) external;
    function convertSynths(string calldata _synth1, string calldata _synth2, address _beneficiary, uint256 _value) external;
    function synthToUSD (string calldata _synth, address _beneficiary, uint256 _value) external;
    function burnUSDbToSettleCollatteralRatio(address _beneficiary) external ;
    function burnUSDbToReleaseCollateral (address _beneficiary, uint256 _value) external ;
    function collectReward(address _beneficiary) external;
    function claimReward(address _beneficiary) external;
    function userRewardDetails(address _beneficiary, uint256 _time) external view returns(uint256 reward, uint256 collectableReward, uint256 earlyRedemptionFee, uint256 investTime);
    function getBYN(address _beneficiary) external view returns(uint256 unstackedBYN, uint256 stackedBYN, uint256 totalBYN);
    function getExchangeDetails() external view returns(uint256 _currentTime, uint256 _collatteralRatio, uint256 _APY, uint256 _tradeFee);
    function setSynthAddress(string calldata _synth, ISynth synthAddress) external ;
    function setBeyondExchangeAddress(address _address) external ;
    function startExchangeProx() external;
    function getCollateralDetails(address _beneficiary) external view returns (uint256 _bUSDValue, uint256 _USDbValueinBYN, uint256 _collatteralValue, uint256 _currentCollatteralRatio);
    function setCollatteralRatio(uint256 _ratio) external;
    function setTradeFeeAndAPY(uint256 _fee, uint256 _APY) external;
    function checkUserCollatteral(address _beneficiary) external view returns (uint256 bUSDAmountInBYN, uint256 collatteralValueInBYN, uint256 additionalBYNValueForCollateral, uint256 additionalCollatteralValueInUSDb, uint256 collatteralRatioUpdated);
    function setAPYInReward(uint256 _APY) external;
    
}

interface ILoanProx {
    function createLoan(uint256 _value, address _beneficiary) external returns(uint256);
    function createLoanUSDb(uint256 _value, address _beneficiary) external returns(uint256);
    function closeLoan(address _beneficiary) external returns(uint256);
    function closeLoanUSDb(address _beneficiary) external returns(uint256);
    function viewLoanDetails(address _address) external view returns(uint256 _collatteralETHb, uint256 _loanValueETHb, uint256 _totalValueAfterLoanFeeETHb, uint256 _loansOfETHb, uint256 _collatteralUSDb, uint256 _loanValueUSDb, uint256 _totalValueAfterLoanFeeUSDb, uint256 _loansOfUSDb);
    function viewLoanConatractDetails() external view returns(uint256 _loanFeeRatio, uint256 _loanCollatteralRatio, uint256 _totalETHb, uint256 _totalUSDb, uint256 _openLoans);
    function setBeyondExchangeAddress(address _address) external;
    function setLoanCollatteralRatio(uint256 _collatteralRatio) external;
    function setLoanFeeRation(uint256 _fee) external;
}

interface IBeyond {
    function balanceCheck(address _beneficiary) external view returns(uint256);
}

interface ISynth{
    
}

contract BeyondExchange is Ownable{
    
    using SafeMath for uint256;

    IBeyondExProx public proxContract;
    IBeyond public beyondToken;
    ILoanProx public LoanContract;
    
    address public beyondTokenAddress;
    address payable wallet;

    constructor(IBeyond _beyondTokenAddress, /*IBeyondExProx _proxContractAddress,ILoanProx _LoanContract,*/ address payable _wallet) public Ownable(msg.sender){
        beyondToken = _beyondTokenAddress;
        //proxContract = _proxContractAddress;
        //LoanContract = _LoanContract;
        wallet = _wallet;
    }
    
    function startExchange() public onlyOwner{
        proxContract.startExchangeProx();
    }
    
    function buybUSD(uint256 _value) public {
        proxContract.mintUSDSynth(_value,msg.sender);
    }

    function mintSynth(string memory _synth, uint256 _value) public{
        proxContract.mintSynth(_synth,msg.sender,_value);
    }

    function convertSynths(string memory _synth1, string memory _synth2, uint256 _value) public {
        proxContract.convertSynths(_synth1,_synth2,msg.sender,_value);
    }
    
    function convertSynthsToUSD(string memory _synth1, uint256 _value) public {
        proxContract.synthToUSD(_synth1,msg.sender,_value);
    }

    function setBeyondExProx(IBeyondExProx _address) public onlyOwner {
        proxContract = _address;
    }
    
    function settleCollatteralRatio() public {
        return proxContract.burnUSDbToSettleCollatteralRatio(msg.sender);
    }
    
    function releaseCollatteralRatio(uint256 _value) public {
        return proxContract.burnUSDbToReleaseCollateral(msg.sender,_value);
    }
    
    function collectUserReward() public {
        proxContract.collectReward(msg.sender);
    }
    
    function claimUserReward() public {
        proxContract.claimReward(msg.sender);
    }
    
    function checkUserReward(uint256 _time, address _beneficiary) public view returns (uint256 reward, uint256 collectableReward, uint256 earlyRedemptionFee, uint256 investTime){
        (reward, collectableReward, earlyRedemptionFee, investTime) = proxContract.userRewardDetails(_beneficiary,_time);
    }
    
    function getBYNDetails(address _beneficiary) public view returns(uint256 unstackedBYN, uint256 stackedBYN, uint256 totalBYN){
        (unstackedBYN,stackedBYN,totalBYN) = proxContract.getBYN(_beneficiary);
    }
    
    function getExchangeProxDetails() external view returns(uint256 _currentTime, uint256 _collatteralRatio, uint256 _APY, uint256 tradeFee){
        (_currentTime,_collatteralRatio,_APY, tradeFee) = proxContract.getExchangeDetails();
    }
    
    function setSynthAddressInProx(string memory _synth, ISynth synthAddress) public onlyOwner {
        proxContract.setSynthAddress(_synth,synthAddress);
    }
    
    function getCollateralDetailsFromProx(address _beneficiary) external view returns (uint256 _bUSDValue, uint256 _USDbValueinBYN, uint256 _collatteralValue, uint256 _currentCollatteralRatio){
        (_bUSDValue, _USDbValueinBYN, _collatteralValue, _currentCollatteralRatio) = proxContract.getCollateralDetails(_beneficiary);
    }
    
    function setCollatteralRatioInProx(uint256 _ratio) public onlyOwner{
        proxContract.setCollatteralRatio(_ratio);
    }
    
    function setTradeFeeAndAPYInProx(uint256 _fee, uint256 _APY) public onlyOwner{
        proxContract.setTradeFeeAndAPY(_fee,_APY);
    }

    function checkUserCollateralProx(address _beneficiary) public view returns (uint256 bUSDAmountInBYN, uint256 collatteralValueInBYN, uint256 additionalBYNValueForCollateral, uint256 additionalCollatteralValueInUSDb, uint256 collatteralRatioUpdated){
        (bUSDAmountInBYN, collatteralValueInBYN, additionalBYNValueForCollateral, additionalCollatteralValueInUSDb, collatteralRatioUpdated) = proxContract.checkUserCollatteral(_beneficiary);
    }
    
    function setAPY(uint256 _APY) public onlyOwner{
        proxContract.setAPYInReward(_APY);
    }
    
    // function setBeyondExchangeAddressInProx(address _address) public onlyOwner{
    //     proxContract.setBeyondExchangeAddress(_address);
    // }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    function getLoan() public payable {
        uint256 _value = LoanContract.createLoan(msg.value,msg.sender);
        wallet.transfer(_value);
    }
    
    function returnLoan() public {
        uint256 _value = LoanContract.closeLoan(msg.sender);
        msg.sender.transfer(_value);
    }
    
    function getLoanUSDb() public payable {
        uint256 _value = LoanContract.createLoanUSDb(msg.value,msg.sender);
        wallet.transfer(_value);
    }
    
    function returnLoanUSDb() public {
        uint256 _value = LoanContract.closeLoanUSDb(msg.sender);
        msg.sender.transfer(_value);
    }
    
    function setLoanProx(ILoanProx _address) public onlyOwner {
        LoanContract = _address;
    }
    
    function getEthLocked() public view returns(uint256){
        return address(this).balance;
    }
    
    function getloanDetails(address _address) public view returns(uint256 _collatteralETHb, uint256 _loanValueETHb, uint256 _totalValueAfterLoanFeeETHb, uint256 _loansOfETHb, uint256 _collatteralUSDb, uint256 _loanValueUSDb, uint256 _totalValueAfterLoanFeeUSDb, uint256 _loansOfUSDb){
        (_collatteralETHb, _loanValueETHb, _totalValueAfterLoanFeeETHb, _loansOfETHb, _collatteralUSDb, _loanValueUSDb, _totalValueAfterLoanFeeUSDb, _loansOfUSDb) =LoanContract.viewLoanDetails(_address);
    }
    
    function getLoanContractDetails() public view returns(uint256 _loanFeeRatio, uint256 _loanCollatteralRatio, uint256 _totalETHb, uint256 _totalUSDb, uint256 _openLoans){
        (_loanFeeRatio, _loanCollatteralRatio, _totalETHb, _totalUSDb, _openLoans) = LoanContract.viewLoanConatractDetails();
    }
    
    function setLoanCollatteralRatioInLoan(uint256 _collatteralRatio) public onlyOwner{
        LoanContract.setLoanCollatteralRatio(_collatteralRatio);
    }
    
    function setLoanFeeRationInLoan(uint256 _fee) public onlyOwner{
        LoanContract.setLoanFeeRation(_fee);
    }
    
    // function setBeyondExchangeAddressInLoan(address _address) public onlyOwner{
    //     LoanContract.setBeyondExchangeAddress(_address);
    // }
    
} 
    