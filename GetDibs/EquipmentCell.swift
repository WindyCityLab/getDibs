//
//  EquipmentCell.swift
//  GetDibs
//
//  Created by Kevin McQuown on 6/13/15.
//  Copyright (c) 2015 Windy City Lab. All rights reserved.
//

import UIKit
import CoreBluetooth

protocol EquipmentCellDelegate
{
    func equipmentCellSwitchTapped(peripheral : BLEPeripheral)
}

class EquipmentCell: UITableViewCell {

    var delegate : EquipmentCellDelegate!

    var peripheral : BLEPeripheral! = nil
    {
        didSet
        {
            nameLabel.text = peripheral.deviceName;
            codeLabel.text = "\(peripheral.deviceID)";
            onOffSwitch.on = peripheral.isOn;
        }
    }

    @IBAction func onOffTapped(sender: AnyObject) {
        onOffSwitch.setOn(peripheral.isOn, animated: false)
        self.delegate.equipmentCellSwitchTapped(peripheral)
    }

    @IBOutlet weak var onOffSwitch: UISwitch!
    @IBOutlet weak var codeLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
}
