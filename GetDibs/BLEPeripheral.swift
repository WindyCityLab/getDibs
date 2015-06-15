//
//  Peripheral.swift
//  GetDibs
//
//  Created by Kevin McQuown on 6/13/15.
//  Copyright (c) 2015 Windy City Lab. All rights reserved.
//

import CoreBluetooth
import Foundation

class BLEPeripheral {

    var peripheral : CBPeripheral! = nil;
    var deviceID : NSData! = nil;
    var deviceName: String! = nil;
    var isOn:Bool = false;
    var timeOfLastAdvertisement : NSDate! = nil;
    var isConnected:Bool = false;

}
