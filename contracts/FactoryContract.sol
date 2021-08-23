pragma solidity ^0.8.4;
import "./gen.sol";
import "./FactoryEvents.sol";
import "./bZxInterfaces/IPriceFeeds.sol";
import "./bZxInterfaces/ILoanToken.sol";
import "./bZxInterfaces/IBZx.sol";
import "./FactoryContractStorage.sol";
import "./dexSwaps.sol";
abstract contract ISmartWallet{
	function executeTradeFactoryOpen(address payable keeper, address iToken, uint loanTokenAmount, address collateralAddress, uint collateralAmount, uint leverage, bytes32 lid,uint feeAmount,bytes memory arbData) external virtual returns(bool success);
	function executeTradeFactoryClose(address payable keeper, bytes32 loanID, uint amount, bool iscollateral,address loanTokenAddress, address collateralAddress,uint feeAmount,bytes memory arbData) external virtual returns(bool success);
	function forceAllowance(address spender, address token, uint amount) external virtual returns(bool);
}
interface UniswapFactory{
	function getPair(address tokenA, address tokenB) external view returns(address pair);
}
interface UniswapPair{
	function token0() external view returns(address);
	function token1() external view returns(address);
	function getReserves() external view returns(uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}
contract FactoryContract is FactoryEvents,FactoryContractStorage{
	modifier onlyOwner(){
		require(msg.sender == owner);_;
	}
	modifier onlySmartWallet(){
		require(isSmartWallet[msg.sender]);_;
	}
	function getSwapAddress() public view returns(address){
		return StateI(bZxRouterAddress).swapsImpl();
	}
    function currentSwapRate(address start, address end) public view returns(uint executionPrice){
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
    function placeOrder(IWalletFactory.OpenOrder memory Order) onlySmartWallet() public{
		require(Order.loanTokenAmount == 0 || Order.collateralTokenAmount == 0); 
        require(currentSwapRate(Order.loanTokenAddress,Order.base) > 0);
		require(Order.orderType <= 2);
		require(Order.orderType > 0 ? collateralTokenMatch(Order) && loanTokenMatch(Order) : true);
        HistoricalOrderIDs[msg.sender]++;
		mainOBID++;
        Order.orderID = HistoricalOrderIDs[msg.sender];
        Order.trader = msg.sender;
		Order.isActive = true;
        HistoricalOrders[msg.sender][HistoricalOrderIDs[msg.sender]] = Order;
		AllOrders[mainOBID].trader = msg.sender;
		AllOrders[mainOBID].orderID = Order.orderID;
        require(sortOrderInfo.addOrderNum(HistOrders[msg.sender],HistoricalOrderIDs[msg.sender]));
		require(sortOrderInfo.addOrderNum(AllOrderIDs,mainOBID));
		matchingID[msg.sender][HistoricalOrderIDs[msg.sender]] = mainOBID;
		if(getActiveTraders.inVals(activeTraders,msg.sender) == false){
			getActiveTraders.addTrader(activeTraders,msg.sender);
		}
        emit OrderPlaced(msg.sender,Order.orderType,Order.price,HistoricalOrderIDs[msg.sender],Order.base,Order.loanTokenAddress);            
    }
    function amendOrder(IWalletFactory.OpenOrder memory Order,uint orderID) onlySmartWallet() public{
		require(Order.loanTokenAmount == 0 || Order.collateralTokenAmount == 0); 
        require(currentSwapRate(Order.loanTokenAddress,Order.base) > 0);
		require(Order.trader == msg.sender);
		require(Order.orderID == HistoricalOrders[msg.sender][orderID].orderID);
		require(Order.isActive == true);
		require(Order.orderType <= 2);
		require(Order.orderType > 0 ? collateralTokenMatch(Order) && loanTokenMatch(Order) : true);
        require(sortOrderInfo.inVals(HistOrders[msg.sender],orderID));
        HistoricalOrders[msg.sender][orderID] = Order;
        emit OrderAmended(msg.sender,Order.orderType,Order.price,orderID,Order.base,Order.loanTokenAddress); 
    }
    function cancelOrder(uint orderID) onlySmartWallet() public{
        require(HistoricalOrders[msg.sender][orderID].isActive == true);
        HistoricalOrders[msg.sender][orderID].isActive = false;
        sortOrderInfo.removeOrderNum(HistOrders[msg.sender],orderID);
		sortOrderInfo.removeOrderNum(AllOrderIDs,matchingID[msg.sender][orderID]);
		if(sortOrderInfo.length(HistOrders[msg.sender]) == 0){
			getActiveTraders.removeTrader(activeTraders,msg.sender);
		}
        emit OrderCancelled(msg.sender,orderID);
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
				if(tradeSize == 0){
					return 0;
				}
				tradeSize = (tradeSize*order.leverage)/1 ether;
			}
		}
		(uint256 fSwapRate,) = order.orderType == 0 ? dexSwaps(getSwapAddress()).dexAmountOut(order.loanTokenAddress,order.base,tradeSize) : dexSwaps(getSwapAddress()).dexAmountOut(order.base,order.loanTokenAddress,order.collateralTokenAmount);
		if(fSwapRate == 0){
			return 0;
		}
		return order.orderType == 0 ? (tradeSize*10**(18-IERC(order.loanTokenAddress).decimals()) * 1 ether)/(fSwapRate*10**(18-IERC(order.base).decimals())) : (1 ether * (fSwapRate*10**(18-IERC(order.loanTokenAddress).decimals())))/(order.collateralTokenAmount*10**(18-IERC(order.base).decimals()));

	}
	function dexSwapCheck(uint collateralTokenAmount, uint loanTokenAmount, address loanTokenAddress, address base, uint leverage,uint orderType) public view returns(uint256){
		uint256 tradeSize;
		if(orderType == 0){
			if(loanTokenAmount > 0){
				tradeSize = (loanTokenAmount*leverage)/1 ether;
			}else{
				(tradeSize,) = dexSwaps(getSwapAddress()).dexAmountOut(base,loanTokenAddress,collateralTokenAmount);
				if(tradeSize == 0){
					return 0;
				}
				tradeSize = (tradeSize*leverage)/1 ether;
			}
		}
		(uint256 fSwapRate,) = orderType == 0 ? dexSwaps(getSwapAddress()).dexAmountOut(loanTokenAddress,base,tradeSize) : dexSwaps(getSwapAddress()).dexAmountOut(base,loanTokenAddress,collateralTokenAmount);
		if(fSwapRate == 0){
			return 0;
		}
		return orderType == 0 ? (tradeSize*10**(18-IERC(loanTokenAddress).decimals()) * 1 ether)/(fSwapRate*10**(18-IERC(base).decimals())) : (1 ether * (fSwapRate*10**(18-IERC(loanTokenAddress).decimals())))/(collateralTokenAmount*10**(18-IERC(base).decimals()));

	}

    function prelimCheck(address smartWallet, uint orderID) public view returns(bool){
        if(HistoricalOrders[smartWallet][orderID].orderType == 0){
			if(HistoricalOrders[smartWallet][orderID].collateralTokenAmount > IERC(HistoricalOrders[smartWallet][orderID].base).balanceOf(smartWallet)){
				return false;
			}
			if(HistoricalOrders[smartWallet][orderID].loanTokenAmount > IERC(HistoricalOrders[smartWallet][orderID].loanTokenAddress).balanceOf(smartWallet)){
				return false;
			}
			uint dSwapValue = dexSwapCheck(HistoricalOrders[smartWallet][orderID].collateralTokenAmount,HistoricalOrders[smartWallet][orderID].loanTokenAmount,HistoricalOrders[smartWallet][orderID].loanTokenAddress,HistoricalOrders[smartWallet][orderID].base,HistoricalOrders[smartWallet][orderID].leverage,0);
			
            if(HistoricalOrders[smartWallet][orderID].price >= dSwapValue && dSwapValue > 0){
                return true;
            }
        }else if(HistoricalOrders[smartWallet][orderID].orderType == 1){
            if(!isActiveLoan(HistoricalOrders[smartWallet][orderID].loanID)){
                return false;
            }
            if(HistoricalOrders[smartWallet][orderID].price <= dexSwapCheck(HistoricalOrders[smartWallet][orderID].collateralTokenAmount,HistoricalOrders[smartWallet][orderID].loanTokenAmount,HistoricalOrders[smartWallet][orderID].loanTokenAddress,HistoricalOrders[smartWallet][orderID].base,HistoricalOrders[smartWallet][orderID].leverage,1)){
                return true;
            }
        }else{
            if(!isActiveLoan(HistoricalOrders[smartWallet][orderID].loanID)){
                return false;
            }
            if(HistoricalOrders[smartWallet][orderID].price >= currentSwapRate(HistoricalOrders[smartWallet][orderID].base,HistoricalOrders[smartWallet][orderID].loanTokenAddress)){
                return true;
            }
        }
        return false;
    }
    function checkIfExecutable(address smartWallet, uint orderID) public view returns(bool){
        IWalletFactory.OpenOrder memory ord = HistoricalOrders[smartWallet][orderID];
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
            if(ord.price >= currentSwapRate(ord.base,OrderLoanTokenIAddress)){
                return true;
            }
        }
        return false;
    }
	function currentDexRate(address dest, address src) public view returns(uint){
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
	function priceCheck(address loanTokenAddress, address base) public view returns(bool){
		uint dexRate = currentDexRate(base,loanTokenAddress);
		uint indexRate = currentSwapRate(base,loanTokenAddress);
		return dexRate >= indexRate ? (dexRate-indexRate)*1000 / dexRate <= 5 ? true : false : (indexRate-dexRate)*1000/ indexRate <= 5 ? true : false;
	}
	function checkCollateralAllowance(IWalletFactory.OpenOrder memory order) internal{
		IERC(order.base).allowance(order.trader,order.iToken) < order.collateralTokenAmount ? ISmartWallet(order.trader).forceAllowance(order.iToken,order.base,order.collateralTokenAmount) : true;
	}
	function checkLoanTokenAllowance(IWalletFactory.OpenOrder memory order) internal{
		IERC(order.loanTokenAddress).allowance(order.trader,order.iToken) < order.loanTokenAmount ? ISmartWallet(order.trader).forceAllowance(order.iToken,order.loanTokenAddress,order.loanTokenAmount) : true;
	}
    function executeOrder(address payable keeper, address smartWallet,uint orderID) public{
		uint256 startGas = gasleft();
        require(isSmartWallet[smartWallet] && HistoricalOrders[smartWallet][orderID].isActive, "non active" );
		HistoricalOrders[smartWallet][orderID].collateralTokenAmount > 0 ? checkCollateralAllowance(HistoricalOrders[smartWallet][orderID]) : checkLoanTokenAllowance(HistoricalOrders[smartWallet][orderID]);
        if(HistoricalOrders[smartWallet][orderID].orderType == 0){
            require(HistoricalOrders[smartWallet][orderID].price >= dexSwapRate(HistoricalOrders[smartWallet][orderID]));
			ISmartWallet(smartWallet).executeTradeFactoryOpen(keeper,HistoricalOrders[smartWallet][orderID].iToken,HistoricalOrders[smartWallet][orderID].loanTokenAmount,HistoricalOrders[smartWallet][orderID].base,HistoricalOrders[smartWallet][orderID].collateralTokenAmount,HistoricalOrders[smartWallet][orderID].leverage,HistoricalOrders[smartWallet][orderID].loanID,startGas,HistoricalOrders[smartWallet][orderID].loanData);
			HistoricalOrders[smartWallet][orderID].isActive = false;
            sortOrderInfo.removeOrderNum(AllOrderIDs,matchingID[smartWallet][orderID]);
			sortOrderInfo.removeOrderNum(HistOrders[smartWallet],orderID);
			if(sortOrderInfo.length(HistOrders[smartWallet]) == 0){
				getActiveTraders.removeTrader(activeTraders,smartWallet);
			}
            emit OrderExecuted(smartWallet,orderID);
            return;
        }
        if(HistoricalOrders[smartWallet][orderID].orderType == 1){
            require(HistoricalOrders[smartWallet][orderID].price <= dexSwapRate(HistoricalOrders[smartWallet][orderID]));
            ISmartWallet(smartWallet).executeTradeFactoryClose(keeper,HistoricalOrders[smartWallet][orderID].loanID,HistoricalOrders[smartWallet][orderID].collateralTokenAmount,HistoricalOrders[smartWallet][orderID].isCollateral, HistoricalOrders[smartWallet][orderID].loanTokenAddress, HistoricalOrders[smartWallet][orderID].base,startGas,HistoricalOrders[smartWallet][orderID].loanData);
            HistoricalOrders[smartWallet][orderID].isActive = false;
            sortOrderInfo.removeOrderNum(AllOrderIDs,matchingID[smartWallet][orderID]);
			sortOrderInfo.removeOrderNum(HistOrders[smartWallet],orderID);
			if(sortOrderInfo.length(HistOrders[smartWallet]) == 0){
				getActiveTraders.removeTrader(activeTraders,smartWallet);
			}
			emit OrderExecuted(smartWallet,orderID);     
            return;
        }
        if(HistoricalOrders[smartWallet][orderID].orderType == 2){
            require(HistoricalOrders[smartWallet][orderID].price >= currentSwapRate(HistoricalOrders[smartWallet][orderID].base,HistoricalOrders[smartWallet][orderID].loanTokenAddress) && priceCheck(HistoricalOrders[smartWallet][orderID].loanTokenAddress,HistoricalOrders[smartWallet][orderID].base));
            ISmartWallet(smartWallet).executeTradeFactoryClose(keeper,HistoricalOrders[smartWallet][orderID].loanID,HistoricalOrders[smartWallet][orderID].collateralTokenAmount,HistoricalOrders[smartWallet][orderID].isCollateral, HistoricalOrders[smartWallet][orderID].loanTokenAddress, HistoricalOrders[smartWallet][orderID].base,startGas,HistoricalOrders[smartWallet][orderID].loanData);
            HistoricalOrders[smartWallet][orderID].isActive = false;
			sortOrderInfo.removeOrderNum(AllOrderIDs,matchingID[smartWallet][orderID]);
            sortOrderInfo.removeOrderNum(HistOrders[smartWallet],orderID);
			if(sortOrderInfo.length(HistOrders[smartWallet]) == 0){
				getActiveTraders.removeTrader(activeTraders,smartWallet);
			}
            emit OrderExecuted(smartWallet,orderID); 
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
    function getOrderByOrderID(address smartWallet, uint orderID) public view returns(IWalletFactory.OpenOrder memory){
        return HistoricalOrders[smartWallet][orderID];
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
	function getTotalActiveOrders() public view returns(uint){
		return sortOrderInfo.length(AllOrderIDs);
	}
	function getOrders(uint start,uint count) public view returns(IWalletFactory.OpenOrder[] memory fullList){
        uint[] memory idSet = sortOrderInfo.enums(AllOrderIDs,start,count);
        
        fullList = new IWalletFactory.OpenOrder[](idSet.length);
        for(uint i = 0;i<idSet.length;i++){
            fullList[i] = getOrderByOrderID(AllOrders[idSet[i]].trader,AllOrders[idSet[i]].orderID);
        }
        return fullList;
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
