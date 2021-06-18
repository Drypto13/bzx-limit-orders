from brownie import *
import time
def main():
    accounts.load('main1')
    factoryAddress = ''
    factoryContract = Contract.from_abi("walletFactor",factoryAddress,walletFactor.abi)
    totalTraders = factoryContract.getToalTradersWithOrders.call()
    getTraderAddresses = factoryContract.getTradersWithOrders.call(0,totalTraders)
    for x in getTraderAddresses:
        totalActiveTrades = factoryContract.getTotalOrders.call(x)
        for y in factoryContract.getActiveOrders.call(x,0,totalActiveTrades):
            if factoryContract.checkIfExecutable.call(x,y):
                print('executable')
            else:
                print('not executable')
    time.sleep(15)
    main()
    
