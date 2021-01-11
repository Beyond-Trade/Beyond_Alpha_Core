pragma solidity ^0.5.16;

import './Ownable.sol';
import './SafeMath.sol';

interface IAggregatorV3Interface{
    function latestRoundData() external view returns(uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract PriceFeed is Ownable{
    using SafeMath for uint256;

    IAggregatorV3Interface internal priceFeed;
    
    mapping( bytes32 => addressesForPrices) public synthKey;
    
    struct addressesForPrices{
        bytes32 synth;
        IAggregatorV3Interface priceFeedAddress;
        uint256 _price;
    }

    /**
     * Network: Rinkeby
     * Aggregator: BTC,ETH,OIL,GBP/USD
     * Address: 0xECe365B379E1dD183B20fc5f022230C044d51404,0x8A753747A1Fa494EC906cE90E9f37563A8AF630e,0x6292aA9a6650aE14fbf974E5029f36F95a1848Fd,0x7B17A813eEC55515Fb8F49F2ef51502bC54DD40F
     */
    constructor() public Ownable(msg.sender){
        
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice(bytes32 _synth) external returns (int) {
        priceFeed = IAggregatorV3Interface(synthKey[_synth].priceFeedAddress);
        
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        // If the round is not complete yet, timestamp is 0
        require(timeStamp > 0, "Round not complete");
        synthKey[_synth]._price = uint256(price).mul(10000000000);
        return price;
    }
    
    function setSynthAddress(string calldata _synth, IAggregatorV3Interface _address) external onlyOwner{
        bytes32 __synth = stringToBytes32(_synth);
        synthKey[__synth].synth = __synth;
        synthKey[__synth].priceFeedAddress = _address;
    }
    
    function stringToBytes32(string memory source) internal pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
    
        assembly {
            result := mload(add(source, 32))
        }
    }
    
    function viewLatestPrice(string memory _synth) public view returns (uint256){
        bytes32 __synth = stringToBytes32(_synth);
        return synthKey[__synth]._price;
    }
}