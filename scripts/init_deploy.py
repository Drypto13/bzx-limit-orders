from brownie import *

def main():
    accounts.load('main3')
    deploy_base_contracts() 
    #print(factory.address)
def deploy_base_contracts():
    factoryContract = FactoryContract.deploy({'from':accounts[0]}) #deploy factory
    factoryContractData = FactoryContractData.deploy({'from':accounts[0]})
    proxyFactory = FactoryContractProxy.deploy("0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B",{'from':accounts[0]})
    sigs = []
    targets = []
    for x in factoryContract.signatures:
        sigs.append(factoryContract.signatures[x])
        targets.append(factoryContract.address)
    for x in factoryContractData.signatures:
        sigs.append(factoryContractData.signatures[x])
        targets.append(factoryContractData.address)
    print(sigs)
    print(targets)
    proxyFactory.setTargets(sigs,targets,{'from':accounts[0]})
    KeeperManagement.deploy(proxyFactory.address,{'from':accounts[0]})
    return proxyFactory

    
    
