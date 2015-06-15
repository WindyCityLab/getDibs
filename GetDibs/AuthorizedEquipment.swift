//
//  AuthorizedEquipment.swift
//  GetDibs
//
//  Created by Kevin McQuown on 6/13/15.
//  Copyright (c) 2015 Windy City Lab. All rights reserved.
//

import Parse

class AuthorizedEquipment: PFObject, PFSubclassing
{
    class func parseClassName() -> String {
        return "AuthorizedEquipment"
    }

    @NSManaged var user : PFUser;
    @NSManaged var machineID : String;
    @NSManaged var name : String;

    class func getAuthorizedMachines(block: PFArrayResultBlock?)
    {
        let q = PFQuery(className: parseClassName());
        q.whereKey("user", equalTo: PFUser.currentUser()!)

        q.findObjectsInBackgroundWithBlock { (results, error) -> Void in
            block!(results,error);
        }
    }
}
