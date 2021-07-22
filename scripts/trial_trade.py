from brownie import *

def main():
    accounts.load('main3')
    factoryContract = "0x4e800fB5D8493120f6Bab3496872b59FCc066A6c" #factory contract address
    factory = Contract.from_abi("walletFactor",factoryContract,walletFactor.abi)
    init_wallet(factory)
    iToken = "0x2E1A74a16e3a9F8e3d825902Ab9fb87c606cB13f"
    ercToken = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"
    setApprovalForWallet(factory,ercToken,iToken)
    trader = factory.getSmartWallet.call(accounts[0])
    nonce = "1"
    submitTrade(Contract.from_abi("SmartWallet",trader,SmartWallet.abi))
    executeOrder(factory,trader,nonce)
def close_pos(smartWallet,loanID,collateral_amount):
    smartWallet.closePosition(loanID,collateral_amount,True,{"from":accounts[0]})
def withdrawERC20(smartWallet,addy):
    smartWallet.withdrawERC20(addy,int(0.001*10**18),{"from":accounts[0]})
def init_wallet(factory):
    factory.createSmartWallet({'from':accounts[0]}) #create a smart wallet
    mySmartWallet = factory.getSmartWallet.call(accounts[0])
    sw = Contract.from_abi("SmartWallet",mySmartWallet,SmartWallet.abi)
    BNB = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"
    ERC20 = interface.IERC(BNB)
    ERC20.transfer(mySmartWallet,1*10**16,{'from':accounts[0]})

def setApprovalForWallet(factory,iERC,spender):
    myWall = factory.getSmartWallet.call(accounts[0])
    smartWallet = Contract.from_abi("SmartWallet",myWall,SmartWallet.abi)
    smartWallet.approveERCSpending(iERC,spender,1000*10**18,{'from':accounts[0]})
def submitTrade(smartWallet):
    loanID = "0x0000000000000000000000000000000000000000000000000000000000000000" #ID of loan, set to loan id if the order is for modifying or closing an active position
    feeAmount = "1" #fee amount denominated in the token that is being used
    iToken = "0x2E1A74a16e3a9F8e3d825902Ab9fb87c606cB13f" #iToken contract address which is the iToken for the currency you want to borrow
    loanToken = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
    price = str(835*10**15) #execution price of order
    leverage = "2000000000000000000" #leverage for position
    lTokenAmount = "0" #loan token amount
    cTokenAmount = str(9*10**15) #collateral token amount
    isActive = True #does not affect for order placement
    base = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270" #collateral token address
    isCollateral = False #only required for closing position orders, carries no effect otherwise
    nonce = "1" #has no effect
    orderType = "0" #0: limit open position 1: limit close position 2: market stop position
    trader = "0x895B36Cde14604309AeF78b53c1D8DE57f05Ab94" #does not matter what is inputted here
    arbData = "" #arbitrary data,not used at this time so leave blank
    tradeOrderStruct = [trader,loanID,feeAmount,iToken,loanToken,price,leverage,lTokenAmount,cTokenAmount,isActive,base,orderType,isCollateral,nonce,arbData]
    smartWallet.submitOrder(tradeOrderStruct,{'from':accounts[0]})
    
def executeOrder(factory,trader,nonce):
    if(factory.checkIfExecutable.call(trader,nonce)):
        factory.executeOrder(trader,nonce,{'from':accounts[0]})
    else:
        print('not executable')

