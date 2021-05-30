pragma solidity ^0.8.4;
import "./FactoryContractStorage.sol";
import "./FactoryEvents.sol";

contract FactoryContractProxy is MainWalletEvents, FactoryContractStorage{
	address internal implementation;
    constructor(){
        owner = msg.sender;
    }
	function setImpl(address nImpl) public {
		require(msg.sender == owner);
		implementation = nImpl;
	}
	function transferOwner(address nOwner) public{
		require(msg.sender == owner);
		owner = nOwner;
	}
    fallback() external payable {
        if (gasleft() <= 2300) {
            return;
        }

        address impl = implementation;

        bytes memory data = msg.data;
        assembly {
            let result := delegatecall(gas(), impl, add(data, 0x20), mload(data), 0, 0)
            let size := returndatasize()
            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
    function replaceImplementation(address impl) public{
        require(msg.sender == owner);
        implementation = impl;
    }	
}