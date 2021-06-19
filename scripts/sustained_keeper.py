from brownie import *
import time
def main():
    accounts.load('main1')
    loop_check()

def loop_check():
    factoryAddress = ''
    factoryContract = interface.IFactory(factoryAddress)
    totalTraders = factoryContract.getTotalTradersWithOrders.call()
    getTraderAddresses = factoryContract.getTradersWithOrders.call(0,totalTraders)
    for x in getTraderAddresses:
        totalActiveTrades = factoryContract.getTotalOrders.call(x)
        for y in factoryContract.getActiveOrderIDs.call(x,0,totalActiveTrades):
            if factoryContract.checkIfExecutable.call(x,y):
                factoryContract.executeOrder(x,y,{'from':accounts[0]})
            else:
                print('not executable')
    time.sleep(15)
    loop_check()
    
