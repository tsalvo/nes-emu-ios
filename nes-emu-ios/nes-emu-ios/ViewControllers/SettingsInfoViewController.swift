//
//  SettingsInfoViewController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/20/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit

class SettingsInfoViewController: UITableViewController
{
    var tableData: [Settings.HelpEntry] = []
    
    private var observation: NSKeyValueObservation?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.observation = self.tableView.observe(\.contentSize) { [weak self] (t, _) in
            self?.navigationController?.preferredContentSize = CGSize(width: 320, height: t.contentSize.height)
        }
        self.applyTheme()
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.register(UINib.init(nibName: SettingsIconTextInfoCell.reuseIdentifier, bundle: nil), forCellReuseIdentifier: SettingsIconTextInfoCell.reuseIdentifier)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.tableData.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cellData: Settings.HelpEntry = self.tableData[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsIconTextInfoCell.reuseIdentifier) as! SettingsIconTextInfoCell
        cell.headerText = cellData.header
        cell.descriptionText = cellData.description
        cell.iconImageNames = cellData.iconNames
        return cell
    }
    
    private func applyTheme()
    {
        self.view.backgroundColor = UIColor.init(named: "SettingsBackground")
    }
}
