from brownie import *
import time
def main():
    accounts.load('main3')
    loop_check()

def loop_check():
    factoryAddress = '0x9952f51F072182172bbEFe38382D45a4E2bb4bEB'
    factoryContract = Contract.from_abi("walletFactor",factoryAddress,walletFactor.abi)
    totalTraders = factoryContract.getTotalTradersWithOrders.call()
    getTraderAddresses = factoryContract.getTradersWithOrders.call(0,totalTraders)
    for x in getTraderAddresses:
        totalActiveTrades = factoryContract.getTotalOrders.call(x)
        for y in factoryContract.getActiveOrderIDs.call(x,0,totalActiveTrades):
            print(factoryContract.getOrderByOrderID(x,y))
            if factoryContract.checkIfExecutable.call(x,y):
                factoryContract.executeOrder(x,y,{'from':accounts[0]})
            else:
                print('not executable')
    time.sleep(15)
    loop_check()
    
