pragma solidity ^0.8.4;
import "./SmartWallet.sol";
contract walletCreator{
    address internal factory;
    address internal owner;
    modifier onlyFactory(){
        require(msg.sender == factory);_;
    }
    modifier onlyOwner(){
        require(msg.sender == owner);_;
    }
    constructor(){
        owner = msg.sender;
    }
    function setFact(address newtarget) public onlyOwner(){
        factory = newtarget;
    }
    function launchWallet(address nOwner) public onlyFactory() returns(address){
        SmartWallet newSmartWallet = new SmartWallet(nOwner,factory);
        return newSmartWallet.getAddress();
    }
}