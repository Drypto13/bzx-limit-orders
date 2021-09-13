from brownie import *

def main():
    accounts.load('main3')
    ob = deploy_base_contracts() 
    print(ob.address)
def deploy_base_contracts():
    orderBook = OrderBook.deploy({'from':accounts[0]}) #deploy factory
    orderBookData = OrderBookData.deploy({'from':accounts[0]})
    proxyOB = OrderBookProxy.deploy("0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B",{'from':accounts[0]})
    sigs = []
    targets = []
    for x in orderBook.signatures:
        sigs.append(orderBook.signatures[x])
        targets.append(orderBook.address)
    for x in orderBookData.signatures:
        sigs.append(orderBookData.signatures[x])
        targets.append(orderBookData.address)
    print(sigs)
    print(targets)
    proxyOB.setTargets(sigs,targets,{'from':accounts[0]})
    KeeperManagement.deploy(proxyOB.address,{'from':accounts[0]})
    return proxyOB

    
    
