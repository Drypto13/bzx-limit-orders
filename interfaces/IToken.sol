/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address _who) external view returns (uint256);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function approve(address _spender, uint256 _value) external returns (bool);
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IToken is IERC20 {
    function tokenPrice() external view returns (uint256);

    function mint(address receiver, uint256 depositAmount)
        external
        returns (uint256);

    function burn(address receiver, uint256 burnAmount)
        external
        returns (uint256 loanAmountPaid);

    function flashBorrow(
        uint256 borrowAmount,
        address borrower,
        address target,
        string calldata signature,
        bytes calldata data
    ) external payable returns (bytes memory);

    function borrow(
        bytes32 loanId, // 0 if new loan
        uint256 withdrawAmount,
        uint256 initialLoanDuration, // duration in seconds
        uint256 collateralTokenSent, // if 0, loanId must be provided; any ETH sent must equal this value
        address collateralTokenAddress, // if address(0), this means ETH and ETH must be sent with the call or loanId must be provided
        address borrower,
        address receiver,
        bytes memory /*loanDataBytes*/ // arbitrary order data (for future use)
    ) external payable returns (LoanOpenData memory);

    function borrowWithGasToken(
        bytes32 loanId, // 0 if new loan
        uint256 withdrawAmount,
        uint256 initialLoanDuration, // duration in seconds
        uint256 collateralTokenSent, // if 0, loanId must be provided; any ETH sent must equal this value
        address collateralTokenAddress, // if address(0), this means ETH and ETH must be sent with the call or loanId must be provided
        address borrower,
        address receiver,
        address gasTokenUser, // specifies an address that has given spend approval for gas/chi token
        bytes memory /*loanDataBytes*/ // arbitrary order data (for future use)
    ) external payable returns (LoanOpenData memory);

    function marginTrade(
        bytes32 loanId, // 0 if new loan
        uint256 leverageAmount,
        uint256 loanTokenSent,
        uint256 collateralTokenSent,
        address collateralTokenAddress,
        address trader,
        bytes memory loanDataBytes // arbitrary order data
    ) external payable returns (LoanOpenData memory);

    function marginTradeWithGasToken(
        bytes32 loanId, // 0 if new loan
        uint256 leverageAmount,
        uint256 loanTokenSent,
        uint256 collateralTokenSent,
        address collateralTokenAddress,
        address trader,
        address gasTokenUser, // specifies an address that has given spend approval for gas/chi token
        bytes memory loanDataBytes // arbitrary order data
    ) external payable returns (LoanOpenData memory);

    function profitOf(address user) external view returns (int256);

    function checkpointPrice(address _user) external view returns (uint256);

    function marketLiquidity() external view returns (uint256);

    function avgBorrowInterestRate() external view returns (uint256);

    function borrowInterestRate() external view returns (uint256);

    function nextBorrowInterestRate(uint256 borrowAmount)
        external
        view
        returns (uint256);

    function supplyInterestRate() external view returns (uint256);

    function nextSupplyInterestRate(uint256 supplyAmount)
        external
        view
        returns (uint256);

    function totalSupplyInterestRate(uint256 assetSupply)
        external
        view
        returns (uint256);

    function totalAssetBorrow() external view returns (uint256);

    function totalAssetSupply() external view returns (uint256);

    function getMaxEscrowAmount(uint256 leverageAmount)
        external
        view
        returns (uint256);

    function assetBalanceOf(address _owner) external view returns (uint256);

    function getEstimatedMarginDetails(
        uint256 leverageAmount,
        uint256 loanTokenSent,
        uint256 collateralTokenSent,
        address collateralTokenAddress // address(0) means ETH
    )
        external
        view
        returns (
            uint256 principal,
            uint256 collateral,
            uint256 interestRate,
            uint256 collateralToLoanRate
        );

    function getDepositAmountForBorrow(
        uint256 borrowAmount,
        uint256 initialLoanDuration, // duration in seconds
        address collateralTokenAddress // address(0) means ETH
    ) external view returns (uint256); // depositAmount

    function getBorrowAmountForDeposit(
        uint256 depositAmount,
        uint256 initialLoanDuration, // duration in seconds
        address collateralTokenAddress // address(0) means ETH
    ) external view returns (uint256 borrowAmount);

    function loanTokenAddress() external view returns (address);

    function baseRate() external view returns (uint256);

    function rateMultiplier() external view returns (uint256);

    function lowUtilBaseRate() external view returns (uint256);

    function lowUtilRateMultiplier() external view returns (uint256);

    function targetLevel() external view returns (uint256);

    function kinkLevel() external view returns (uint256);

    function maxScaleRate() external view returns (uint256);

    function checkpointSupply() external view returns (uint256);

    function initialPrice() external view returns (uint256);

    function loanParamsIds(uint256) external view returns (bytes32);

    struct LoanOpenData {
        bytes32 loanId;
        uint256 principal;
        uint256 collateral;
    }
}