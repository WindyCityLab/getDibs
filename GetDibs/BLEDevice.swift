//
//  LoopTrackDisplay.swift
//  LEBluetooth
//
//  Created by Kevin McQuown on 5/24/15.
//  Copyright (c) 2015 Windy City Lab. All rights reserved.
//

import Foundation
import CoreBluetooth

let kServiceID = "15e9a83f-88bd-41e4-8f7c-3aec6e5229e6"
let kMD5HashSalt = "6A2041DB-5942-44D7-844C-8C17D7926107"
let kCBAdvDataLocalName = "kCBAdvDataLocalName"
let kCBAdvDataManufacturerData = "kCBAdvDataManufacturerData"
let kCatalyzeDeviceName = "kCatalyzeDeviceName"
var sendingFirstHalf = true;

private let sharedBLEDevice = BLEDevice()

protocol BLEDeviceDelegate
{
    func connectionStateDidUpdate();
}

class BLEDevice : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate
{
    var justAuthorized = true;

    let kScanCheckTime = 30.0;
    var hashtoSend : NSData! = nil
    var commandtoSend : NSData! = nil
    var centralNode : CBCentralManager! = nil
    var serviceUUID : CBUUID! = nil;
    var peripherals : [String:BLEPeripheral] = [:]
    var peripheralsArray : [BLEPeripheral] = Array();
    var notifyOnUpdate : CBCharacteristic! = nil;
    var writeToPeripheral : CBCharacteristic! = nil;
    var selectedPeripheral : BLEPeripheral? = nil;
    var selectedPeripheralUUID : String = ""
    {
        didSet
        {
            selectedPeripheral = peripherals[selectedPeripheralUUID];
        }
    }
    var timer : NSTimer! = nil;

    var deviceName : String! = nil;
    var deviceID : NSData! = nil;

    var delegate : BLEDeviceDelegate! = nil;

    class var sharedInstance : BLEDevice
    {
        return sharedBLEDevice;
    }

    func begin()
    {
        if self.timer == nil
        {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(kScanCheckTime, target: self, selector: Selector("timerFired:"), userInfo: nil, repeats: true);
        }

        peripherals.removeAll(keepCapacity: true);
        peripheralsArray.removeAll(keepCapacity: true);
        
        serviceUUID = CBUUID(string: kServiceID);
        centralNode = CBCentralManager(delegate: self, queue: nil, options:["CBCentralManagerOptionRestoreIdentifierKey":kCatalyzeDeviceName]);
    }

    func timerFired(timer: NSTimer)
    {
        var keysToRemove : [String] = Array()
        for (key,p) in peripherals
        {
            if p.timeOfLastAdvertisement.timeIntervalSinceNow < -kScanCheckTime
            {
                keysToRemove.append(key)
            }
        }
        for key in keysToRemove
        {
            peripherals.removeValueForKey(key)
        }
        updatePeripheralsArray()
        if keysToRemove.count > 0
        {
            self.delegate.connectionStateDidUpdate()
        }
    }

    func refresh()
    {
        self.delegate.connectionStateDidUpdate()
    }

    func removeConnection(forPeripheral : BLEPeripheral)
    {
        forPeripheral.peripheral.setNotifyValue(false, forCharacteristic: notifyOnUpdate);
        forPeripheral.peripheral.setNotifyValue(false, forCharacteristic: writeToPeripheral);
        centralNode.cancelPeripheralConnection(forPeripheral.peripheral);
    }

    //MARK:

    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        println("did discover services for peripheral");
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

    func peripheral(peripheral: CBPeripheral!, didWriteValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        println("receiving data");

        if error !=  nil
        {
            justAuthorized = true;
            removeConnection(peripherals[peripheral.identifier.UUIDString]!);
            return;
        }
        
        if justAuthorized
        {
            println("sending the following: \(commandtoSend) of size: \(commandtoSend.length)");
            // send on or off command
            peripheral.writeValue(commandtoSend, forCharacteristic: writeToPeripheral, type: CBCharacteristicWriteType.WithResponse)
            justAuthorized = false
        }
        else
        {
            removeConnection(peripherals[peripheral.identifier.UUIDString]!);
            justAuthorized = true;
        }
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
                    println("sending the following: \(hashtoSend) of size: \(hashtoSend.length)");
                    
                    peripheral.writeValue(hashtoSend, forCharacteristic: writeToPeripheral, type: CBCharacteristicWriteType.WithResponse)
                    
                  //  peripheral.writeValue(commandtoSend, forCharacteristic: writeToPeripheral, type: CBCharacteristicWriteType.WithResponse)

                default :
                    ()
            }
        }
    }
    //MARK:

    func updatePeripheralsArray()
    {
        peripheralsArray.removeAll(keepCapacity: true)
        for (key, value) in peripherals
        {
            peripheralsArray.append(value)
        }
    }
    func addPeripheralToSetOfPeripherals(peripheral : BLEPeripheral)
    {
        peripherals[peripheral.peripheral.identifier.UUIDString] = peripheral
        updatePeripheralsArray()
    }

    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!)
    {
        //println("did discover peripheral \(peripheral.identifier)");
        //println("advertisement data: \(advertisementData)");

        var p = BLEPeripheral();
        p.peripheral = peripheral;
        p.deviceName = advertisementData[kCBAdvDataLocalName] as? String;
        p.timeOfLastAdvertisement = NSDate()
        p.deviceID = (advertisementData[kCBAdvDataManufacturerData] as? NSData)?.subdataWithRange(NSMakeRange(0, 2));

        var onOffData = (advertisementData[kCBAdvDataManufacturerData] as? NSData)!.subdataWithRange(NSMakeRange(2, 1))
        //println("\(onOffData)")
        p.isOn = ("\(onOffData)" == "<01>");
        addPeripheralToSetOfPeripherals(p)

        self.delegate.connectionStateDidUpdate()
        peripheral.delegate = self;
    }

    func timeAsString() -> String
    {
        var todaysDate:NSDate = NSDate()
        var dateFormatter:NSDateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "HHmm"
        var DateInFormat:String = dateFormatter.stringFromDate(todaysDate)
        println(DateInFormat)
        return DateInFormat
    }
    func send(command : String, toPeripheral : BLEPeripheral)
    {
        var actualHash = kMD5HashSalt + timeAsString()
        println(actualHash)
        var md5Hash = actualHash.MD5()
        println("sending: \(md5Hash)");
        self.hashtoSend = md5Hash.dataUsingEncoding(NSUTF8StringEncoding)
        self.commandtoSend = "1".dataUsingEncoding(NSUTF8StringEncoding)
        centralNode.connectPeripheral(toPeripheral.peripheral, options: nil);
    
    }

    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        println("did connect to peripheral");
        let p =  peripherals[peripheral.identifier.UUIDString]!
        p.isConnected = true;
        peripheral.discoverServices(nil)
    }

    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        println("Peripheral Disconnected...");
        let p = peripherals[peripheral.identifier.UUIDString]!
        p.isConnected = false;
        delegate.connectionStateDidUpdate()
        central.scanForPeripheralsWithServices([serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey:NSNumber(bool: true)]);
    }

    func centralManagerDidUpdateState(central: CBCentralManager!) {
        println("central manager did update state");
        switch central.state
        {
            case CBCentralManagerState.PoweredOn:
                println("Scanning for Peripherals with service id: \(serviceUUID)");
                central.scanForPeripheralsWithServices([serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey:NSNumber(bool: true)]);

            default:
                ()
        }
    }
}