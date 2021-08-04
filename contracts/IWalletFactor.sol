pragma solidity ^0.8.4;
interface IWalletFactory{
    struct OpenOrder{
        address trader;
        bytes32 loanID;
        address iToken;
		address loanTokenAddress;
        uint price;
        uint leverage;
        uint loanTokenAmount;
        uint collateralTokenAmount;
        bool isActive;
        address base;
        uint orderType;
        bool isCollateral;
        uint orderID;
        bytes loanData;
    }
    function getRouter() external view returns(address);
    function placeOrder(OpenOrder calldata Order) external;
    function amendOrder(OpenOrder calldata Order, uint orderID) external;
    function cancelOrder(uint orderID) external;
	function getSwapAddress() external view returns(address);
	function getFeed() external view returns(address);
    
}