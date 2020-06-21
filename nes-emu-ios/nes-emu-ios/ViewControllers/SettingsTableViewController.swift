//
//  SettingsTableViewController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/20/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit

class SettingsTableViewController: UITableViewController
{
    // MARK: - Private Cariables
    
    private let tableData: [Settings.Section] = [
        Settings.Section(
            sectionName: NSLocalizedString("settings-section-audio", comment: "Audio"),
            cells: [
                Settings.Cell(
                    key: Settings.sampleRateKey,
                    title: NSLocalizedString("settings-item-audio-sample-rate", comment: "Sample Rate"),
                    description: NSLocalizedString("settings-item-audio-sample-rate-description", comment: "(kHz)"),
                    metadata: SampleRate.allCases,
                    type: Settings.CellType.Segmented),
                Settings.Cell(
                    key: Settings.audioFiltersEnabledKey,
                    title: NSLocalizedString("settings-item-audio-filtering", comment: "Audio filtering"),
                    description: NSLocalizedString("settings-item-audio-filtering-description", comment: "(low pass / high pass)"),
                    type: Settings.CellType.Toggle),
                Settings.Cell(
                    key: Settings.audioSessionNotifyOthersOnDeactivationKey,
                    title: NSLocalizedString("settings-item-resume-other-audio", comment: "Resume other audio"),
                    description: NSLocalizedString("settings-item-resume-other-audio-description", comment: "when exiting game"),
                    type: Settings.CellType.Toggle),
                ]
            )
        ]
    
    private var observation: NSKeyValueObservation?
    
    // MARK: - Life Cycle
        
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.observation = self.tableView.observe(\.contentSize) { [weak self] (t, _) in
            self?.navigationController?.preferredContentSize = CGSize(width: 320, height: t.contentSize.height)
        }
        self.popoverPresentationController?.backgroundColor = UIColor.systemBackground
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.register(UINib.init(nibName: SettingsToggleCell.reuseIdentifier, bundle: nil), forCellReuseIdentifier: SettingsToggleCell.reuseIdentifier)
        self.tableView.register(UINib.init(nibName: SettingsAboutCell.reuseIdentifier, bundle: nil), forCellReuseIdentifier: SettingsAboutCell.reuseIdentifier)
        self.tableView.register(UINib.init(nibName: SettingsMoreInfoCell.reuseIdentifier, bundle: nil), forCellReuseIdentifier: SettingsMoreInfoCell.reuseIdentifier)
        self.tableView.register(UINib.init(nibName: SettingsSegmentedCell.reuseIdentifier, bundle: nil), forCellReuseIdentifier: SettingsSegmentedCell.reuseIdentifier)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        self.preferredContentSize = CGSize(width: 320, height: self.tableView.contentSize.height)
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return self.tableData.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.tableData[section].cells.count
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let view: UIView = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        let label: UILabel = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 16.0, weight: UIFont.Weight.semibold)
        label.text = (self.tableData[section].sectionName ?? "")
        label.textColor = UIColor.label
        view.addSubview(label)
        
        view.addConstraints([
            NSLayoutConstraint(item: label, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: 0),
            NSLayoutConstraint(item: label, attribute: .leadingMargin, relatedBy: .equal, toItem: view, attribute: .leadingMargin, multiplier: 1.0, constant: 8)])
        
        return view
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cellData: Settings.Cell = self.tableData[indexPath.section].cells[indexPath.row]
        
        switch cellData.type {
        case .Toggle:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsToggleCell.reuseIdentifier) as! SettingsToggleCell
            cell.settingText = cellData.title ?? ""
            cell.settingDescriptionText = cellData.description
            cell.settingKey = cellData.key
            
            return cell
            
        case .About:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsAboutCell.reuseIdentifier) as! SettingsAboutCell
            cell.aboutText1 = cellData.title ?? ""
            cell.aboutText2 = cellData.description ?? ""
            
            return cell
            
        case .Info:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsMoreInfoCell.reuseIdentifier) as! SettingsMoreInfoCell
            cell.settingText = cellData.title ?? ""
            
            return cell
            
        case .Segmented:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSegmentedCell.reuseIdentifier) as! SettingsSegmentedCell
            cell.settingText = cellData.title ?? ""
            cell.settingDescriptionText = cellData.description
            if let key = cellData.key,
                let values: [SettingsEnum] = cellData.metadata as? [SettingsEnum]
            {
                cell.settingTuple = (key: key, values: values)
            }
            
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let cellData: Settings.Cell = self.tableData[indexPath.section].cells[indexPath.row]
        
        switch cellData.type
        {
        case .Info:
            self.performSegue(withIdentifier: "showMoreInfo", sender: cellData.metadata)
        default: break
        }
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        return 30
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if let safeSettingsInfoVC = segue.destination as? SettingsInfoViewController,
            let safeTableData = sender as? [Settings.HelpEntry]
        {
            safeSettingsInfoVC.tableData = safeTableData
        }
    }
}
