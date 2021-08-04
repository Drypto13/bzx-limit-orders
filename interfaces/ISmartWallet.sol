pragma solidity ^0.8.4;

interface ISmartWallet{
    struct OpenOrder{
        address trader;
        bytes32 loanID;
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
    struct LoanReturnData {
        bytes32 loanId; // id of the loan
        uint96 endTimestamp; // loan end timestamp
        address loanToken; // loan token address
        address collateralToken; // collateral token address
        uint256 principal; // principal amount of the loan
        uint256 collateral; // collateral amount of the loan
        uint256 interestOwedPerDay; // interest owned per day
        uint256 interestDepositRemaining; // remaining unspent interest
        uint256 startRate; // collateralToLoanRate
        uint256 startMargin; // margin with which loan was open
        uint256 maintenanceMargin; // maintenance margin
        uint256 currentMargin; /// current margin
        uint256 maxLoanTerm; // maximum term of the loan
        uint256 maxLiquidatable; // current max liquidatable
        uint256 maxSeizable; // current max seizable
        uint256 depositValueAsLoanToken; // net value of deposit denominated as loanToken
        uint256 depositValueAsCollateralToken; // net value of deposit denominated as collateralToken
    }
	function getBZXRouter() external virtual view returns(address);
	function withdrawBNB(uint amount) external;
	function gasPrice(address payToken) external virtual view returns(uint);
	
	function submitOrder(OpenOrder memory Order) external;
	function amendActiveOrder(OpenOrder memory Order, uint nonce) external;
	function cancelOrder(uint nonce) external;
	function openPosition(bytes32 loanId, address iToken, uint loanTokenAmount, address collateralAddress, uint collateralAmount, uint leverage) external returns(bool);
	function closePosition(bytes32 loanId,uint amount, bool iscollateral)  external;
	function withdrawERC20(address tokenAddress,uint amount) external;
	function approveERCSpending(address ercContract, address spendContract, uint amount) external;
	function getAddress() external returns(address);
	function getTotalOpenLoans() external virtual view returns(LoanReturnData[] memory);




}