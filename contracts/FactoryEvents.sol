pragma solidity ^0.8.4;
import "./EnumLimits.sol";
import "./EnumTraders.sol";
import "./IWalletFactor.sol";
import "./IERC.sol";
contract FactoryEvents{
    using sortOrderInfo for sortOrderInfo.orderSet;
    mapping(address=>bool) internal  hasSmartWallet;
    mapping(address=>address) internal smartWalletOwnership;
    mapping(address=>bool) internal isSmartWallet;
    mapping(address=>mapping(uint=>IWalletFactory.OpenOrder)) internal HistoricalOrders;
    mapping(address=>sortOrderInfo.orderSet) internal HistOrders;
    mapping(address=>uint) internal HistoricalOrderIDs;
	getActiveTraders.orderSet internal activeTraders;
    event NewWallet(address indexed owner,address indexed newSmartWallet);
    event OrderCancelled(address indexed smartWallet,uint nonce);
    event OrderPlaced(address indexed smartWallet, uint indexed OrderType, uint indexed execPrice,uint orderID, address collateralTokenAddress, address loanTokenAddress);
    event OrderExecuted(address indexed smartWallet,uint nonce);
    event OrderAmended(address indexed smartWallet, uint indexed OrderType, uint indexed execPrice,uint orderID, address collateralTokenAddress, address loanTokenAddress);
    function _safeTransfer(address token,address to,uint256 amount,string memory error) internal {
        _callOptionalReturn(token,abi.encodeWithSelector(IERC(token).transfer.selector, to, amount),error);
    }

    function _safeTransferFrom(address token,address from,address to,uint256 amount,string memory error) internal {
        _callOptionalReturn(token,abi.encodeWithSelector(IERC(token).transferFrom.selector, from, to, amount),error);
    }

    function _callOptionalReturn(address token,bytes memory data,string memory error) internal {
        (bool success, bytes memory returndata) = token.call(data);
        require(success, error);
        if (returndata.length != 0) {
            require(abi.decode(returndata, (bool)), error);
        }
    }
}