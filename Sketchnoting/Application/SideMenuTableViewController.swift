//
//  SideMenuTableViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SideMenuTableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.backgroundView?.backgroundColor = #colorLiteral(red: 0.2605174184, green: 0.2605243921, blue: 0.260520637, alpha: 1)
        header.textLabel?.textColor = .white
        header.textLabel?.font = UIFont(name: "Helvetica-Bold", size: 14)
    }

}
