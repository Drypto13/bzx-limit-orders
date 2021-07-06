from brownie import *

def main():
    accounts.load('main1')
    factory = deploy_base_contracts() 
    print(factory.address)
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
    
    
