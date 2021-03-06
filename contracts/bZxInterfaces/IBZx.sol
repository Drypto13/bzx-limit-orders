pragma solidity ^0.8.4;
abstract contract IBZx{
    enum LoanType {
        All,
        Margin,
        NonMargin
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
        function closeWithSwap(
        bytes32 loanId,
        address receiver,
        uint256 swapAmount, // denominated in collateralToken
        bool returnTokenIsCollateral, // true: withdraws collateralToken, false: withdraws loanToken
        bytes calldata loanDataBytes)
        external virtual
        returns (
            uint256 loanCloseAmount,
            uint256 withdrawAmount,
            address withdrawToken);
    function getUserLoans(
        address user,
        uint256 start,
        uint256 count,
        LoanType loanType,
        bool isLender,
        bool unsafeOnly)
        external virtual
        view
        returns (LoanReturnData[] memory loansData);
    function getUserLoansCount(
        address user,
        bool isLender)
        external virtual
        view
        returns (uint256);
    function getLoan(
        bytes32 loanId)
        external virtual
        view
        returns (LoanReturnData memory loanData);
}