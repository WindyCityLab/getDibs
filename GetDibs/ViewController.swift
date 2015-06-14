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

    var equipment : BLEDevice! = nil;
    var authorizedMachines : [String:String] = [:]

    func connectionStateDidUpdate() {
        tableView.reloadData()
    }

    func equipmentCellSwitchTapped(peripheral: BLEPeripheral) {
        if peripheral.isOn
        {
            peripheral.isOn = false;
            self.equipment.send("O", toPeripheral: peripheral);
            self.tableView.reloadData()
        }
        else
        {
            let confirm = UIAlertController(title: "Please Confirm", message: "Do you want to turn \(peripheral.deviceName) on?", preferredStyle: UIAlertControllerStyle.Alert)
            let ok = UIAlertAction(title: "YES", style: UIAlertActionStyle.Destructive, handler: { (action) -> Void in
                self.equipment.send("X", toPeripheral: peripheral);
                peripheral.isOn = true;
                self.tableView.reloadData();
            })
            let cancel = UIAlertAction(title: "NO", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
                ()
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
        let item = equipment.peripheralsArray[indexPath.row]
        cell.peripheral = item
        cell.onOffSwitch.enabled = false;
        if authorizedMachines["\(item.deviceID)"] != nil
        {
            cell.onOffSwitch.enabled = true;
        }
        return cell
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if equipment == nil
        {
            return 0;
        }
        return equipment.peripheralsArray.count;
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
//        equipment.toggleConnection(equipment.peripheralsArray[indexPath.row])
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
        AuthorizedEquipment.getAuthorizedMachines({ (machines, error) -> Void in
            self.authorizedMachines.removeAll(keepCapacity: true)
            for machine in machines!
            {
                let m = machine as! AuthorizedEquipment
                self.authorizedMachines["<\(m.machineID)>"] = ""
            }
            self.equipment = BLEDevice.sharedInstance;
            self.equipment.delegate = self;
            self.equipment.begin();
            self.tableView.reloadData()
        })
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
            self.authorizedMachines.removeAll(keepCapacity: true)
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
        NSNotificationCenter.defaultCenter().addObserverForName(kPushReceived, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
            self.queryAuthorizedEquipment()
        }
//        PFUser.logOut()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

