pragma solidity ^0.8.4;
import "./SmartWalletStorage.sol";
import "./FactoryEvents.sol";
abstract contract iFactory{
	function getSmartWalletLogic() external virtual view returns(address);
}
contract SmartWalletProxy is FactoryEvents, SmartWalletStorage{
    constructor(address setOwnership,address setFactoryContract){
        owner = setOwnership;
        factoryContract = setFactoryContract;
        //ProtocolLike(bZxRouter).priceFeeds()
    }
    fallback() external payable {
        if (gasleft() <= 2300) {
            return;
        }

        address impl = iFactory(factoryContract).getSmartWalletLogic();

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
    function getAddress() public view returns(address self){
        self = address(this);
    }
}