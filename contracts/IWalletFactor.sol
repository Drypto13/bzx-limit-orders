pragma solidity ^0.8.4;
interface IWalletFactory{
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
    function getRouter() external view returns(address);
    function placeOrder(OpenOrder calldata Order) external;
    function amendOrder(OpenOrder calldata Order, uint nonce) external;
    function cancelOrder(uint nonce) external;
    
}