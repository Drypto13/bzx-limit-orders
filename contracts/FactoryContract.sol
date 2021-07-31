pragma solidity ^0.8.4;
import "./gen.sol";
import "./FactoryEvents.sol";
import "./bZxInterfaces/IPriceFeeds.sol";
import "./bZxInterfaces/ILoanToken.sol";
import "./bZxInterfaces/IBZx.sol";
import "./FactoryContractStorage.sol";
abstract contract ISmartWallet{
	function executeTradeFactoryOpen(address payable keeper, address iToken, uint loanTokenAmount, address collateralAddress, uint collateralAmount, uint leverage, bytes32 lid,uint feeAmount,bytes memory arbData) external virtual returns(bool success);
	function executeTradeFactoryClose(address payable keeper, bytes32 loanID, uint amount, bool iscollateral,address loanTokenAddress, address collateralAddress,uint feeAmount,bytes memory arbData) external virtual returns(bool success);
	function forceAllowance(address spender, address token, uint amount) external virtual returns(bool);
}
interface dexSwaps{
    function dexExpectedRate(address sourceTokenAddress,address destTokenAddress,uint256 sourceTokenAmount) external virtual view returns (uint256);
    function dexAmountOut(address sourceTokenAddress,address destTokenAddress,uint256 amountIn) external virtual view returns (uint256 amountOut, address midToken);
    function dexAmountIn(address sourceTokenAddress,address destTokenAddress,uint256 amountOut) external virtual view returns (uint256 amountIn, address midToken);

}
interface UniswapFactory{
	function getPair(address tokenA, address tokenB) external view returns(address pair);
}
interface UniswapPair{
	function token0() external view returns(address);
	function token1() external view returns(address);
	function getReserves() external view returns(uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}
contract walletFactor is MainWalletEvents,FactoryContractStorage{
	modifier onlyOwner(){
		require(msg.sender == owner);_;
	}
	function getSwapAddress() public view returns(address){
		return StateI(bZxRouterAddress).swapsImpl();
	}
    function currentSwapRate(address end, address start) public view returns(uint executionPrice){
        (executionPrice,)=IPriceFeeds(getFeed()).queryRate(start,end);
    }
    function getFeed() public view returns (address){
        return StateI(bZxRouterAddress).priceFeeds();
    }
    function getRouter() public view returns (address) {
        return bZxRouterAddress;
    }
    function setGenerator(address nGen) onlyOwner() public{
		walletGen = nGen;
	}
	function setWalletLogic(address nTarget) onlyOwner() public{
		smartWalletLogic = nTarget;
	}
    function placeOrder(IWalletFactory.OpenOrder memory Order) public{
		require(Order.loanTokenAmount == 0 || Order.collateralTokenAmount == 0, "both are non-zero"); 
        require(isSmartWallet[msg.sender],"not a smart wallet");
        require(currentSwapRate(Order.base,Order.loanTokenAddress) > 0,"no exchange rate");
        HistoricalOrdersNonce[msg.sender]++;
        Order.nonce = HistoricalOrdersNonce[msg.sender];
        Order.trader = msg.sender;
		Order.isActive = true;
        HistoricalOrders[msg.sender][HistoricalOrdersNonce[msg.sender]] = Order;
        require(sortOrderInfo.addOrderNum(HistOrders[msg.sender],HistoricalOrdersNonce[msg.sender]));
		if(getActiveTraders.inVals(activeTraders,msg.sender) == false){
			getActiveTraders.addTrader(activeTraders,msg.sender);
		}
        emit OrderPlaced(msg.sender,Order.orderType,Order.price,HistoricalOrdersNonce[msg.sender],Order.base,Order.loanTokenAddress);            
    }
    function amendOrder(IWalletFactory.OpenOrder memory Order,uint nonce) public{
		require(Order.loanTokenAmount == 0 || Order.collateralTokenAmount == 0); 
        require(isSmartWallet[msg.sender]);
        require(currentSwapRate(Order.base,Order.loanTokenAddress) > 0);
		require(Order.trader == msg.sender);
		require(Order.nonce == HistoricalOrders[msg.sender][nonce].nonce);
		require(Order.isActive == true);
        require(sortOrderInfo.inVals(HistOrders[msg.sender],nonce));
        HistoricalOrders[msg.sender][nonce] = Order;
        emit OrderAmended(msg.sender,Order.orderType,Order.price,nonce,Order.base,Order.loanTokenAddress); 
    }
    function cancelOrder(uint nonce) public{
        require(isSmartWallet[msg.sender]);
        require(HistoricalOrders[msg.sender][nonce].isActive == true);
        HistoricalOrders[msg.sender][nonce].isActive = false;
        sortOrderInfo.removeOrderNum(HistOrders[msg.sender],nonce);
		if(sortOrderInfo.length(HistOrders[msg.sender]) == 0){
			getActiveTraders.removeTrader(activeTraders,msg.sender);
		}
        emit OrderCancelled(msg.sender,nonce);
    }
    function collateralTokenMatch(IWalletFactory.OpenOrder memory checkOrder) internal view returns(bool){
        return IBZx(getRouter()).getLoan(checkOrder.loanID).collateralToken == checkOrder.base;
    }
    function loanTokenMatch(IWalletFactory.OpenOrder memory checkOrder) internal view returns(bool){
        return IBZx(getRouter()).getLoan(checkOrder.loanID).loanToken == checkOrder.loanTokenAddress;
    }
    function isActiveLoan(bytes32 ID) internal view returns(bool){
        return IBZx(getRouter()).getLoan(ID).loanId == ID && ID != 0;
    }
	function dexSwapRate(IWalletFactory.OpenOrder memory order) public view returns(uint256){
		uint256 tradeSize;
		if(order.orderType == 0){
			if(order.loanTokenAmount > 0){
				tradeSize = (order.loanTokenAmount*order.leverage)/1 ether;
			}else{
				(tradeSize,) = dexSwaps(getSwapAddress()).dexAmountOut(order.base,order.loanTokenAddress,order.collateralTokenAmount);
				tradeSize = (tradeSize*order.leverage)/1 ether;
			}
		}
		(uint256 fSwapRate,) = order.orderType == 0 ? dexSwaps(getSwapAddress()).dexAmountOut(order.loanTokenAddress,order.base,tradeSize) : dexSwaps(getSwapAddress()).dexAmountOut(order.base,order.loanTokenAddress,order.collateralTokenAmount);
		return order.orderType == 0 ? (tradeSize*10**(18-IERC(order.loanTokenAddress).decimals()) * 1 ether)/(fSwapRate*10**(18-IERC(order.base).decimals())) : (1 ether * (fSwapRate*10**(18-IERC(order.loanTokenAddress).decimals())))/(order.collateralTokenAmount*10**(18-IERC(order.base).decimals()));
	}
    function checkIfExecutable(address smartWallet, uint nonce) public view returns(bool){
        IWalletFactory.OpenOrder memory ord = HistoricalOrders[smartWallet][nonce];
        address OrderLoanTokenIAddress = ord.loanTokenAddress;
        if(!isSmartWallet[smartWallet]){
            return false;
        }
        if(!ord.isActive){
            return false;
        }

        if(ord.orderType == 0){
			if(ord.collateralTokenAmount > IERC(ord.base).balanceOf(smartWallet)){
				return false;
			}
			if(ord.loanTokenAmount > IERC(OrderLoanTokenIAddress).balanceOf(smartWallet)){
				return false;
			}
            if(ord.price >= dexSwapRate(ord)){
                return true;
            }
        }
        if(ord.orderType == 1){
            if(!isActiveLoan(ord.loanID)){
                return false;
            }
            if(!collateralTokenMatch(ord) || !loanTokenMatch(ord)){
                return false;
            }
            if(ord.price <= dexSwapRate(ord)){
                return true;
            }
        }
        if(ord.orderType == 2){
            if(!isActiveLoan(ord.loanID)){
                return false;
            }
            if(!collateralTokenMatch(ord) || !loanTokenMatch(ord)){
                return false;
            }
            if(ord.price >= currentSwapRate(OrderLoanTokenIAddress,ord.base)){
                return true;
            }
        }
        return false;
    }
	function currentDexRate(address src, address dest) public view returns(uint){
		uint dexRate;
		if(src == BNBAddress || dest == BNBAddress){
			address pairAddress = UniswapFactory(UniFactoryContract).getPair(src,dest);
			(uint112 reserve0,uint112 reserve1,) = UniswapPair(pairAddress).getReserves();
			uint256 res0 = uint256(reserve0);
			uint256 res1 = uint256(reserve1);
			dexRate = UniswapPair(pairAddress).token0() == src ? (res0*10**(18-IERC(UniswapPair(pairAddress).token0()).decimals()+18))/(res1*10**(18-IERC(UniswapPair(pairAddress).token1()).decimals())) : (res1*10**(18-IERC(UniswapPair(pairAddress).token1()).decimals()+18))/res0*10**(18-IERC(UniswapPair(pairAddress).token0()).decimals());
		}else{
			address pairAddress0 = UniswapFactory(UniFactoryContract).getPair(src,BNBAddress);
			(uint112 reserve0,uint112 reserve1,) = UniswapPair(pairAddress0).getReserves();
			uint256 res0 = uint256(reserve0);
			uint256 res1 = uint256(reserve1);
			uint midSwapRate = UniswapPair(pairAddress0).token0() == BNBAddress ? (res1*10**(18-IERC(UniswapPair(pairAddress0).token1()).decimals()+18))/(res0*10**(18-IERC(UniswapPair(pairAddress0).token0()).decimals())) : (res0*10**(18-IERC(UniswapPair(pairAddress0).token0()).decimals()+18))/(res1*10**(18-IERC(UniswapPair(pairAddress0).token0()).decimals()));
			address pairAddress1 = UniswapFactory(UniFactoryContract).getPair(dest,BNBAddress);
			(uint112 reserve2,uint112 reserve3,) = UniswapPair(pairAddress1).getReserves();
			uint256 res2 = uint256(reserve2);
			uint256 res3 = uint256(reserve3);
			dexRate = UniswapPair(pairAddress1).token0() == BNBAddress ? ((10**36/((res3*10**(18-IERC(UniswapPair(pairAddress1).token1()).decimals()+18))/(res2*10**(18-IERC(UniswapPair(pairAddress1).token0()).decimals()))))*midSwapRate)/10**18 : ((10**36/((res2*10**(18-IERC(UniswapPair(pairAddress1).token0()).decimals()+18))/(res3*10**(18-IERC(UniswapPair(pairAddress1).token1()).decimals()))))*midSwapRate)/10**18;
		}
		return dexRate;
	}
	function priceCheck(IWalletFactory.OpenOrder memory monitoredOrder) public view returns(bool){
		monitoredOrder.collateralTokenAmount = 10+10**IERC(monitoredOrder.base).decimals();
		uint dexRate = currentDexRate(monitoredOrder.loanTokenAddress,monitoredOrder.base);
		uint indexRate = currentSwapRate(monitoredOrder.loanTokenAddress,monitoredOrder.base);
		return dexRate >= indexRate ? (dexRate-indexRate)*1000 / dexRate <= 5 ? true : false : (indexRate-dexRate)*1000/ indexRate <= 5 ? true : false;
	}
	function checkCollateralAllowance(IWalletFactory.OpenOrder memory order) internal{
		IERC(order.base).allowance(order.trader,order.iToken) < order.collateralTokenAmount ? ISmartWallet(order.trader).forceAllowance(order.iToken,order.base,1 ether * 1 ether) : true;
	}
	function checkLoanTokenAllowance(IWalletFactory.OpenOrder memory order) internal{
		IERC(order.loanTokenAddress).allowance(order.trader,order.iToken) < order.loanTokenAmount ? ISmartWallet(order.trader).forceAllowance(order.iToken,order.loanTokenAddress,1 ether * 1 ether) : true;
	}
    function executeOrder(address payable smartWallet,uint nonce) public{
        require(isSmartWallet[smartWallet] && HistoricalOrders[smartWallet][nonce].isActive, "non active" );
		HistoricalOrders[smartWallet][nonce].collateralTokenAmount > 0 ? checkCollateralAllowance(HistoricalOrders[smartWallet][nonce]) : checkLoanTokenAllowance(HistoricalOrders[smartWallet][nonce]);
        if(HistoricalOrders[smartWallet][nonce].orderType == 0){
            require(HistoricalOrders[smartWallet][nonce].price >= dexSwapRate(HistoricalOrders[smartWallet][nonce]));
			ISmartWallet(smartWallet).executeTradeFactoryOpen(payable(msg.sender),HistoricalOrders[smartWallet][nonce].iToken,HistoricalOrders[smartWallet][nonce].loanTokenAmount,HistoricalOrders[smartWallet][nonce].base,HistoricalOrders[smartWallet][nonce].collateralTokenAmount,HistoricalOrders[smartWallet][nonce].leverage,HistoricalOrders[smartWallet][nonce].loanID,HistoricalOrders[smartWallet][nonce].feeAmount,HistoricalOrders[smartWallet][nonce].loanData);

			HistoricalOrders[smartWallet][nonce].isActive = false;
            sortOrderInfo.removeOrderNum(HistOrders[smartWallet],nonce);
			if(sortOrderInfo.length(HistOrders[smartWallet]) == 0){
				getActiveTraders.removeTrader(activeTraders,smartWallet);
			}
            emit OrderExecuted(smartWallet,nonce);
            return;
        }
        if(HistoricalOrders[smartWallet][nonce].orderType == 1){
            require(HistoricalOrders[smartWallet][nonce].price <= dexSwapRate(HistoricalOrders[smartWallet][nonce]));
            
            ISmartWallet(smartWallet).executeTradeFactoryClose(payable(msg.sender),HistoricalOrders[smartWallet][nonce].loanID,HistoricalOrders[smartWallet][nonce].collateralTokenAmount,HistoricalOrders[smartWallet][nonce].isCollateral, HistoricalOrders[smartWallet][nonce].loanTokenAddress, HistoricalOrders[smartWallet][nonce].base,HistoricalOrders[smartWallet][nonce].feeAmount,HistoricalOrders[smartWallet][nonce].loanData);
            HistoricalOrders[smartWallet][nonce].isActive = false;
            sortOrderInfo.removeOrderNum(HistOrders[smartWallet],nonce);
			if(sortOrderInfo.length(HistOrders[smartWallet]) == 0){
				getActiveTraders.removeTrader(activeTraders,smartWallet);
			}
			emit OrderExecuted(smartWallet,nonce);     
            return;
        }
        if(HistoricalOrders[smartWallet][nonce].orderType == 2){
            require(HistoricalOrders[smartWallet][nonce].price >= currentSwapRate(HistoricalOrders[smartWallet][nonce].loanTokenAddress,HistoricalOrders[smartWallet][nonce].base) && priceCheck(HistoricalOrders[smartWallet][nonce]));
            //require(isProperExecutionTime(smartWallet));
            ISmartWallet(smartWallet).executeTradeFactoryClose(payable(msg.sender),HistoricalOrders[smartWallet][nonce].loanID,HistoricalOrders[smartWallet][nonce].collateralTokenAmount,HistoricalOrders[smartWallet][nonce].isCollateral, HistoricalOrders[smartWallet][nonce].loanTokenAddress, HistoricalOrders[smartWallet][nonce].base,HistoricalOrders[smartWallet][nonce].feeAmount,HistoricalOrders[smartWallet][nonce].loanData);
            HistoricalOrders[smartWallet][nonce].isActive = false;
            sortOrderInfo.removeOrderNum(HistOrders[smartWallet],nonce);
			if(sortOrderInfo.length(HistOrders[smartWallet]) == 0){
				getActiveTraders.removeTrader(activeTraders,smartWallet);
			}
            emit OrderExecuted(smartWallet,nonce); 
            return;
        }
    }
    function getActiveOrders(address smartWallet, uint start, uint count) public view returns(IWalletFactory.OpenOrder[] memory fullList){
        uint[] memory idSet = sortOrderInfo.enums(HistOrders[smartWallet],start,count);
        
        fullList = new IWalletFactory.OpenOrder[](idSet.length);
        for(uint i = 0;i<idSet.length;i++){
            fullList[i] = HistoricalOrders[smartWallet][idSet[i]];
        }
        return fullList;
    }
    function getOrderByOrderID(address smartWallet, uint orderID) public view returns(IWalletFactory.OpenOrder memory rOrder){
        rOrder = HistoricalOrders[smartWallet][orderID];
    }
    function getActiveOrderIDs(address smartWallet, uint start, uint count) public view returns(uint[] memory){
        return sortOrderInfo.enums(HistOrders[smartWallet],start,count);
    }
    function getTotalOrders(address smartWallet) public view returns(uint){
        return sortOrderInfo.length(HistOrders[smartWallet]);
    }
	function getTradersWithOrders(uint start, uint count) public view returns(address[] memory){
		return getActiveTraders.enums(activeTraders,start,count);
	}
	function getTotalTradersWithOrders() public view returns(uint){
		return getActiveTraders.length(activeTraders);
	}
    function createSmartWallet() public{
        require(hasSmartWallet[msg.sender] != true);
        address newWallet = walletCreator(walletGen).launchWallet(msg.sender);
        hasSmartWallet[msg.sender] = true;
        smartWalletOwnership[msg.sender] = newWallet;
        isSmartWallet[newWallet] = true;
        emit NewWallet(msg.sender,newWallet);
    }
    function getSmartWallet(address walletOwner) public view returns(address wallet){
        wallet = smartWalletOwnership[walletOwner];
    }
    function ownsSmartWallet(address walletOwner) public view returns(bool ownership){
        ownership = hasSmartWallet[walletOwner];
    }
	function getSmartWalletLogic() public view returns(address){
		return smartWalletLogic;
	}
}
