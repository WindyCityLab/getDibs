//
//  Equipment.swift
//  GetDibs
//
//  Created by Kevin McQuown on 6/18/15.
//  Copyright (c) 2015 Windy City Lab. All rights reserved.
//

import Parse

class Equipment: PFObject, PFSubclassing
{
    class func parseClassName() -> String {
        return "Equipment"
    }

    @NSManaged var machineID : String;
    @NSManaged var name : String;

    class func getAllEquipment(block: PFArrayResultBlock?)
    {
        let q = PFQuery(className: parseClassName());

        q.findObjectsInBackgroundWithBlock { (results, error) -> Void in
            block!(results,error);
        }
    }
}
