pragma solidity ^0.8.4;
import "./bZxInterfaces/ILoanToken.sol";
import "./bZxInterfaces/IBZx.sol";
import "./IERC.sol";
import "./bZxInterfaces/IPriceFeeds.sol";
import "./IWalletFactor.sol";
import "./FactoryEvents.sol";
import "./SmartWalletStorage.sol";
import "./dexSwaps.sol";
import "./Utils/SafeMath.sol";
contract SmartWallet is FactoryEvents,SmartWalletStorage{
	using SafeMath for uint256;
    modifier onlyFactory(){
        require(msg.sender == factoryContract,"not factory");_;
    }
    modifier onlyOwner(){
        require(msg.sender == owner, "not owner");_;
    }
    fallback() external payable{}
    receive() external payable{}
    function withdrawBNB(uint amount) public onlyOwner(){
        payable(msg.sender).call{value:amount}("");
    }
    function getBZXRouter() public view returns (address){
        return IWalletFactory(factoryContract).getRouter();
    }
	function gasPrice(address payToken) public view returns(uint){
		return IPriceFeeds(IWalletFactory(factoryContract).getFeed()).getFastGasPrice(payToken)*2;
	}
    function executeTradeFactoryOpen(address payable keeper, address iToken, uint loanTokenAmount, address collateralAddress, uint collateralAmount, uint leverage, bytes32 lid,uint startGas,bytes memory arbData) onlyFactory() public returns(bool success){
		bytes memory blankByte = "";
		arbData = blankByte;
		LoanTokenI(iToken).marginTrade(lid,leverage,loanTokenAmount,collateralAmount,collateralAddress,address(this),arbData);
		uint256 gasUsed = startGas - gasleft();
		address usedToken = collateralAmount > loanTokenAmount ? collateralAddress : LoanTokenI(iToken).loanTokenAddress();
        _safeTransfer(usedToken,keeper,(gasUsed.mul(gasPrice(usedToken))).div(1e36),"");     
        success = true;
    }
    function executeTradeFactoryClose(address payable keeper, bytes32 loanID, uint amount, bool iscollateral,address loanTokenAddress, address collateralAddress,uint startGas,bytes memory arbData) onlyFactory() public returns(bool success){
        bytes memory blankByte = "";
		arbData = blankByte;
        IBZx(getBZXRouter()).closeWithSwap(loanID, address(this), amount, iscollateral, arbData);
		if((iscollateral == true && collateralAddress != BNBAddress) || (iscollateral == false && loanTokenAddress != BNBAddress)){
			uint256 gasUsed = startGas - gasleft();
			address usedToken = iscollateral ? collateralAddress : loanTokenAddress;
			_safeTransfer(usedToken,keeper,(gasUsed.mul(gasPrice(usedToken))).div(1e36),"");
		}else{
			uint256 gasUsed = startGas - gasleft();
			keeper.call{value:(gasUsed.mul(gasPrice(BNBAddress))).div(1e36)}("");
			WBNB(BNBAddress).deposit{value:address(this).balance}();
		}
        success = true;
    }
    function submitOrder(IWalletFactory.OpenOrder memory Order) onlyOwner() public{
        IWalletFactory(factoryContract).placeOrder(Order);
    }
    function amendOrder(IWalletFactory.OpenOrder memory Order, uint nonce) onlyOwner() public{
        IWalletFactory(factoryContract).amendOrder(Order,nonce);
    }
    function cancelOrder(uint nonce) onlyOwner() public{
        IWalletFactory(factoryContract).cancelOrder(nonce);
    }
    function openPosition(bytes32 loanId, address iToken, uint loanTokenAmount, address collateralAddress, uint collateralAmount, uint leverage, bytes memory arbData) onlyOwner() public returns(bool success){
        LoanTokenI(iToken).marginTrade(loanId,leverage,loanTokenAmount,collateralAmount,collateralAddress,address(this),arbData);
        success = true;
    }
    function closePosition(bytes32 loanId,uint amount, bool iscollateral, bytes memory arbData)  public{
        IBZx(getBZXRouter()).closeWithSwap(loanId, address(this), amount, iscollateral, arbData);
    }
    function withdrawERC20(address tokenAddress,uint amount) onlyOwner() public{
        _safeTransfer(tokenAddress,msg.sender,amount,"");
    }
    function approveERCSpending(address ercContract, address spendContract, uint amount) public onlyOwner(){
        IERC(ercContract).approve(spendContract,amount);
    }
    function getAddress() public view returns(address self){
        self = address(this);
    }
    function forceAllowance(address spender, address token, uint amount) onlyFactory() public returns(bool){
        IERC(token).approve(spender,amount);
		return true;
    }
    function getTotalOpenLoans() public view returns(IBZx.LoanReturnData[] memory){
        return IBZx(getBZXRouter()).getUserLoans(address(this),0,IBZx(getBZXRouter()).getUserLoansCount(address(this),false),IBZx.LoanType.Margin,false,false);
    }
}

