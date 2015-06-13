//
//  LoopTrackDisplay.swift
//  LEBluetooth
//
//  Created by Kevin McQuown on 5/24/15.
//  Copyright (c) 2015 Windy City Lab. All rights reserved.
//

import Foundation
import CoreBluetooth

//let kServiceID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
let kServiceID = "15e9a83f-88bd-41e4-8f7c-3aec6e5229e6"
let kCBAdvDataLocalName = "kCBAdvDataLocalName"
let kCBAdvDataManufacturerData = "kCBAdvDataManufacturerData"

private let sharedBLEDevice = BLEDevice()

protocol BLEDeviceDelegate
{
    func connectionStateDidUpdate();
}

class BLEDevice : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate
{

    var centralNode : CBCentralManager! = nil
    var serviceUUID : CBUUID! = nil;
    var loopTrackPeripheral : CBPeripheral! = nil;
    var notifyOnUpdate : CBCharacteristic! = nil;
    var writeToPeripheral : CBCharacteristic! = nil;

    var deviceName : String! = nil;
    var deviceID : NSData! = nil;

    var delegate : BLEDeviceDelegate! = nil;

    class var sharedInstance : BLEDevice
    {
        return sharedBLEDevice;
    }

    func begin()
    {
        serviceUUID = CBUUID(string: kServiceID);
        centralNode = CBCentralManager(delegate: self, queue: nil, options:["CBCentralManagerOptionRestoreIdentifierKey":"loopTrackCentralManager"]);
    }

    func refresh()
    {
        self.delegate.connectionStateDidUpdate()
    }

    func sendCommand(command : String)
    {
        let data = command.dataUsingEncoding(NSUTF8StringEncoding)
        loopTrackPeripheral.writeValue(data, forCharacteristic: writeToPeripheral, type: CBCharacteristicWriteType.WithResponse)
    }

    func isConnected() -> Bool
    {
        return (loopTrackPeripheral != nil)
        //        println("Connected services: \(centralNode.retrieveConnectedPeripheralsWithServices([serviceUUID]).count)");
        //        return centralNode.retrieveConnectedPeripheralsWithServices([serviceUUID]).count > 0;
    }

    func removeConnection()
    {
        if (loopTrackPeripheral != nil)
        {
            loopTrackPeripheral.setNotifyValue(false, forCharacteristic: notifyOnUpdate);
            loopTrackPeripheral.setNotifyValue(false, forCharacteristic: writeToPeripheral);
            centralNode.cancelPeripheralConnection(loopTrackPeripheral);
        }
    }

    func createConnection()
    {
        centralNode.scanForPeripheralsWithServices([serviceUUID], options: nil);
    }

    //MARK:

    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        println("did discover services for loop track display");
        for service in peripheral.services
        {
            println("service: \(service.UUID)")
            peripheral.discoverCharacteristics(nil, forService: service as! CBService)
        }
    }

    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        let messsage = NSString(data: characteristic.value, encoding: NSUTF8StringEncoding);
        println("didupdatevalueforcharacteristic: \(characteristic.value) -- \(messsage)");
    }

    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        for characteristic in service.characteristics
        {
            delegate.connectionStateDidUpdate();
            switch (characteristic as! CBCharacteristic).properties
            {
            case CBCharacteristicProperties.Notify :
                peripheral.setNotifyValue(true, forCharacteristic: characteristic as! CBCharacteristic)
                notifyOnUpdate = characteristic as! CBCharacteristic
                println("added notify characteristic for service \(service.UUID)");
            case CBCharacteristicProperties.Write :
                writeToPeripheral = characteristic as! CBCharacteristic
                println("added write characteristic for service \(service.UUID)");
            default :
                ()
            }
        }
    }
    //MARK:

    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!)
    {
        println("did discover loop track display");
        println("advertisement data: \(advertisementData)");
        self.deviceName = advertisementData[kCBAdvDataLocalName] as? String;
        self.deviceID = advertisementData[kCBAdvDataManufacturerData] as? NSData;
        central.stopScan();
        loopTrackPeripheral = peripheral;
        loopTrackPeripheral.delegate = self;
        central.connectPeripheral(loopTrackPeripheral, options: nil);
    }

    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        println("did connect to peripheral");
        loopTrackPeripheral.delegate = self;
        peripheral.discoverServices(nil)
    }
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        println("Peripheral Disconnected...");
        delegate.connectionStateDidUpdate()
        central.scanForPeripheralsWithServices([serviceUUID], options: nil);
    }

    func centralManagerDidUpdateState(central: CBCentralManager!) {
        println("central manager did update state");
        switch central.state
        {
        case CBCentralManagerState.PoweredOn:
            println("Scanning for Peripherals with service id: \(serviceUUID)");
            central.scanForPeripheralsWithServices([serviceUUID], options: nil)

        default:
            ()
        }
    }
}