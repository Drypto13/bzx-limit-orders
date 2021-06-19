pragma solidity ^0.8.4;
interface IFactory{
    struct OpenOrder{
        address trader;
        bytes32 loanID;
        uint feeAmount;
        address iToken;
        uint price;
        uint leverage;
        uint loanTokenAmount;
        uint collateralTokenAmount;
        bool isActive;
        address base;
        uint orderType;
        bool isCollateral;
        uint nonce;
        
    }
	function currentSwapRate(address end, address start) external virtual view returns(uint);
	function getFeed() external virtual view returns(address);
	function getRouter() external virtual pure returns(address);
	function checkIfExecutable(address smartWallet, uint nonce) external virtual view returns(bool);
	function executeOrder(address payable smartWallet,uint nonce) external virtual;
	function getActiveOrders(address smartWallet, uint start, uint count) external virtual view returns(OpenOrder[] memory);
	function getOrderByOrderID(address smartWallet, uint orderId) external virtual view returns(OpenOrder memory);
	function getActiveOrderIDs(address smartWallet, uint start, uint count) external virtual view returns(uint[] memory);
	function getTotalOrders(address smartWallet) external virtual view returns(uint);
	function getTradersWithOrders(uint start, uint count) external virtual view returns(address[] memory);
	function getTotalTradersWithOrders() external virtual view returns(uint);
	function createSmartWallet() external;
	function getSmartWallet(address walletOwner) external virtual view returns(address);
	function ownsSmartWallet(address walletOwner) external virtual view returns(bool);
	function getSmartWalletLogic() external virtual view returns(address);

}