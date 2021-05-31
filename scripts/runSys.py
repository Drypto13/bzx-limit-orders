from brownie import *

def main():
    accounts.load('main1')
    factory = deploy_base_contracts() 
    init_wallet(factory)
    iToken = "0x7343b25c4953f4C57ED4D16c33cbEDEFAE9E8Eb9"
    ercToken = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
    setApprovalForWallet(factory,ercToken,iToken)
    trader = factory.getSmartWallet.call(accounts[0])
    nonce = "1"
    submitTrade(Contract.from_abi("SmartWallet",trader,SmartWallet.abi))
    executeOrder(factory,trader,nonce)
def close_pos(smartWallet,loanID,collateral_amount):
    smartWallet.closePosition(loanID,collateral_amount,True,{"from":accounts[0]})
def withdrawERC20(smartWallet,addy):
    smartWallet.withdrawERC20(addy,int(0.001*10**18),{"from":accounts[0]})
def deploy_base_contracts():
    factoryContract = walletFactor.deploy({'from':accounts[0]}) #deploy factory
    smartW = SmartWallet.deploy({'from':accounts[0]})
    proxyFactory = FactoryContractProxy.deploy({'from':accounts[0]})
    proxyFactory.setImpl(factoryContract.address,{'from':accounts[0]})
    walletCreation = walletCreator.deploy({'from':accounts[0]}) #deploy wallet generator
    walletCreation.setFact(proxyFactory.address,{'from':accounts[0]}) #assign the factory address to the generator
    proxyContract = Contract.from_abi("walletFactor",proxyFactory.address,walletFactor.abi)
    proxyContract.setWalletLogic(smartW.address,{'from':accounts[0]})
    proxyContract.setGenerator(walletCreation.address,{'from':accounts[0]}) #assign generatory address to factory
    return proxyContract
def init_wallet(factory):
    factory.createSmartWallet({'from':accounts[0]}) #create a smart wallet
    mySmartWallet = factory.getSmartWallet.call(accounts[0])
    sw = Contract.from_abi("SmartWallet",mySmartWallet,SmartWallet.abi)
    BNB = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
    ERC20 = interface.IERC(BNB)
    ERC20.transfer(mySmartWallet,1*10**16,{'from':accounts[0]})

def setApprovalForWallet(factory,iERC,spender):
    myWall = factory.getSmartWallet.call(accounts[0])
    smartWallet = Contract.from_abi("SmartWallet",myWall,SmartWallet.abi)
    smartWallet.approveERCSpending(iERC,spender,1000*10**18,{'from':accounts[0]})
def submitTrade(smartWallet):
    loanID = "0x0000000000000000000000000000000000000000000000000000000000000000" #ID of loan, set to loan id if the order is for modifying or closing an active position
    feeAmount = "1" #fee amount denominated in the token that is being used
    iToken = "0x7343b25c4953f4C57ED4D16c33cbEDEFAE9E8Eb9" #iToken contract address which is the iToken for the currency you want to borrow
    price = str(400*10**18) #execution price of order
    leverage = "2000000000000000000" #leverage for position
    lTokenAmount = "0" #loan token amount
    cTokenAmount = str(9*10**15) #collateral token amount
    isActive = True #does not affect for order placement
    base = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c" #collateral token address
    isCollateral = False #only required for closing position orders, carries no effect otherwise
    nonce = "1" #has no effect
    orderType = "0" #0: limit open position 1: limit close position 2: market stop position
    trader = "0x895B36Cde14604309AeF78b53c1D8DE57f05Ab94" #does not matter what is inputted here
    tradeOrderStruct = [trader,loanID,feeAmount,iToken,price,leverage,lTokenAmount,cTokenAmount,isActive,base,orderType,isCollateral,nonce]
    smartWallet.submitOrder(tradeOrderStruct,{'from':accounts[0]})
    
def executeOrder(factory,trader,nonce):
    if(factory.checkIfExecutable.call(trader,nonce)):
        factory.executeOrder(trader,nonce,{'from':accounts[0]})
    else:
        print('not executable')
    
    
