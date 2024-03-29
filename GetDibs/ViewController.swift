//
//  ViewController.swift
//  GetDibs
//
//  Created by Kevin McQuown on 6/13/15.
//  Copyright (c) 2015 Windy City Lab. All rights reserved.
//

import UIKit
import Parse

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, BLEDeviceDelegate, PFLogInViewControllerDelegate, EquipmentCellDelegate {

    @IBOutlet weak var tableView: UITableView!

    var bleDevice : BLEDevice! = nil;
    var allEquipment : [String : Equipment] = [:]
    var authorizedEquipment : [String:Equipment] = [:]

    func connectionStateDidUpdate() {
        tableView.reloadData()
    }

    func equipmentCellSwitchTapped(peripheral: BLEPeripheral) {
        if peripheral.isOn
        {
            peripheral.isOn = false;
            self.bleDevice.send("0", toPeripheral: peripheral);
            self.tableView.reloadData()
        }
        else
        {
            let e = allEquipment["\(peripheral.deviceID)"];
            let confirm = UIAlertController(title: "Please Confirm", message: "Do you want to turn \(e!.name) on?", preferredStyle: UIAlertControllerStyle.Alert)
            let ok = UIAlertAction(title: "YES", style: UIAlertActionStyle.Destructive, handler: { (action) -> Void in
                self.bleDevice.send("1", toPeripheral: peripheral);
                peripheral.isOn = true;
                self.tableView.reloadData();
            })
            let cancel = UIAlertAction(title: "NO", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
                self.tableView.reloadData()
            })
            confirm.addAction(cancel)
            confirm.addAction(ok)
            presentViewController(confirm, animated: true, completion: nil)
        }
    }
    @IBAction func refreshButtonTapped(sender: AnyObject) {
        queryAuthorizedEquipment()
    }

    //MARK:
    //MARK: Tableview delegates and datasource
    //MARK:
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("equipmentCell") as! EquipmentCell
        cell.delegate = self
        let item = bleDevice.peripheralsArray[indexPath.row]
        cell.peripheral = item
        cell.onOffSwitch.enabled = false;
        if let equipment = allEquipment["\(item.deviceID)"]
        {
            cell.nameLabel.text = equipment.name;
        }
        else
        {
            cell.nameLabel.text = "Not yet in Parse";
        }
        cell.accessoryType = UITableViewCellAccessoryType.None
        cell.onOffSwitch.enabled = false;
        if authorizedEquipment["\(item.deviceID)"] != nil
        {
            cell.onOffSwitch.enabled = true;
            cell.accessoryType = UITableViewCellAccessoryType.Checkmark
        }
        return cell
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if bleDevice == nil
        {
            return 0;
        }
        return bleDevice.peripheralsArray.count;
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        let item = bleDevice.peripheralsArray[indexPath.row];
        let equipment = allEquipment["\(item.deviceID)"]
        

        
        
        let alert = UIAlertController(title: "Edit Equipment ID", message: "Change to any 4 digit number", preferredStyle: .Alert)
        alert.addTextFieldWithConfigurationHandler { (textField) -> Void in
            textField.placeholder = "NAME";
            textField.text = equipment?.name
        }
        
        alert.addTextFieldWithConfigurationHandler { (textField) -> Void in
            textField.placeholder = "XXXX";
            textField.text = equipment?.machineID
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel) { (action) -> Void in
            ()
        }
        let submit = UIAlertAction(title: "Change", style: UIAlertActionStyle.Destructive) { (action) -> Void in
            let IDTextField = alert.textFields?.last as! UITextField
            let nameTextField = alert.textFields?.first as! UITextField
            self.bleDevice.send("2\(IDTextField.text)", toPeripheral: item)
            equipment?.name = nameTextField.text
            equipment?.machineID = IDTextField.text

            equipment?.saveInBackgroundWithBlock({ (success, error) -> Void in
                if !success
                {
                    //Throw an error
                }else
                {
                    println("object saved")
                 //   self.queryAuthorizedEquipment()

                }
            })
            
        }
        alert.addAction(cancel);
        alert.addAction(submit);
        presentViewController(alert, animated: true, completion: nil);
    }

    //MARK:
    //MARK: Parse cloud work
    //MARK:

    func logInViewController(logInController: PFLogInViewController, didLogInUser user: PFUser) {
        logInController.dismissViewControllerAnimated(true, completion: nil)
        queryAuthorizedEquipment();
    }

    func queryAuthorizedEquipment()
    {
        Equipment.getAllEquipment { (equipments, error) -> Void in
            self.allEquipment.removeAll(keepCapacity: true)
            for equipment in equipments!
            {
                let e = equipment as! Equipment
                self.allEquipment["<\(e.machineID)>"] = e;
            }
            AuthorizedEquipment.getAuthorizedMachines({ (machines, error) -> Void in
                self.authorizedEquipment.removeAll(keepCapacity: true)
                for machine in machines!
                {
                    let m = machine as! AuthorizedEquipment
                    self.authorizedEquipment["<\(m.equipment.machineID)>"] = m.equipment
                }
                self.bleDevice = BLEDevice.sharedInstance;
                self.bleDevice.delegate = self;
                self.bleDevice.begin();
                self.tableView.reloadData()
            })
        }
    }

    //MARK:
    //MARK: Viewcontroller lifecycle
    //MARK:

    override func viewWillAppear(animated: Bool) {

        super.viewWillAppear(animated)

        if PFUser.currentUser() == nil
        {
            let login = PFLogInViewController()
            login.delegate = self;
            self.authorizedEquipment.removeAll(keepCapacity: true)
            presentViewController(login, animated: true, completion: { () -> Void in
                ()
            })
        }
        else
        {
            queryAuthorizedEquipment()
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Get Dibs"
        NSNotificationCenter.defaultCenter().addObserverForName(kPushReceived, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
            self.queryAuthorizedEquipment()
        }
    //    PFUser.logOut()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

