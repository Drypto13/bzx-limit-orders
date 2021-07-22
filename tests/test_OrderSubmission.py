import pytest
from brownie import Contract, Wei, reverts
from fixedint import *

@pytest.fixture(scope="module", autouse=True)
def shared_setup(module_isolation):
    pass
@pytest.fixture(scope="module")
def deploy_limit_contracts(bzx,accounts,walletFactor,SmartWallet,FactoryContractProxy,walletCreator):
    factoryContract = walletFactor.deploy({'from':accounts[0]}) #deploy factory
    smartW = SmartWallet.deploy({'from':accounts[0]})
    proxyFactory = FactoryContractProxy.deploy(bzx.address,{'from':accounts[0]})
    proxyFactory.setImpl(factoryContract.address,{'from':accounts[0]})
    walletCreation = walletCreator.deploy({'from':accounts[0]}) #deploy wallet generator
    walletCreation.setFact(proxyFactory.address,{'from':accounts[0]}) #assign the factory address to the generator
    proxyContract = Contract.from_abi("walletFactor",proxyFactory.address,walletFactor.abi)
    print(smartW.address)
    proxyContract.setWalletLogic(smartW.address,{'from':accounts[0]})
    proxyContract.setGenerator(walletCreation.address,{'from':accounts[0]}) #assign generatory address to factory
    return proxyContract
@pytest.fixture(scope="module")
def deploy_smart_wallet(accounts,deploy_limit_contracts,LINK,SmartWallet):
    deploy_limit_contracts.createSmartWallet({'from':accounts[0]})
    mySmartWallet = deploy_limit_contracts.getSmartWallet(accounts[0].address)
    sw = Contract.from_abi("SmartWallet",mySmartWallet,SmartWallet.abi)
    return deploy_limit_contracts, sw
def test_order_submission(Constants, bzx, DAI, LINK, accounts, web3, deploy_smart_wallet,LoanToken):
    main_contract, smart_wallet = deploy_smart_wallet
    print(main_contract.getFeed())
    smart_wallet.approveERCSpending(LINK.address,accounts[1],10000e18,{'from':accounts[0]})
    loanID = "0x0000000000000000000000000000000000000000000000000000000000000000" #ID of loan, set to loan id if the order is for modifying or closing an active position
    feeAmount = "1" #fee amount denominated in the token that is being used
    iToken = accounts[1].address #iToken contract address which is the iToken for the currency you want to borrow
    price = int(2*10**18) #execution price of order
    leverage = "2000000000000000000" #leverage for position
    lTokenAmount = 0 #loan token amount
    cTokenAmount = int(9*10**15) #collateral token amount
    isActive = True #does not affect for order placement
    base = LINK.address #collateral token address
    isCollateral = False #only required for closing position orders, carries no effect otherwise
    nonce = "1" #has no effect
    orderType = "0" #0: limit open position 1: limit close position 2: market stop position
    trader = accounts[1].address #does not matter what is inputted here
    arbData = ""
    tradeOrderStruct = [trader,loanID,feeAmount,iToken,DAI.address,price,leverage,lTokenAmount,cTokenAmount,isActive,base,orderType,isCollateral,nonce,arbData]
    smart_wallet.submitOrder(tradeOrderStruct,{'from':accounts[0]})
    assert(main_contract.getTotalOrders(smart_wallet.address) == 1)
    assert(main_contract.getOrderByOrderID(smart_wallet,1)[4] == DAI.address)
    print(main_contract.dexSwapRate(tradeOrderStruct))
