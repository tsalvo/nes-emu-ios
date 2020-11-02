//
//  SettingsTableViewController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/20/20.
//  Copyright © 2020 Tom Salvo.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import UIKit

class SettingsTableViewController: UITableViewController, SettingsConfirmationDelegate
{
    // MARK: - Private Variables
    
    private let tableData: [Settings.Section] = [
        Settings.Section(
            sectionName: NSLocalizedString("settings-section-general", comment: "General"),
            cells: [
                Settings.Cell(
                    key: Settings.autoSaveKey,
                    title: NSLocalizedString("settings-item-autosave", comment: "Autosave"),
                    description: NSLocalizedString("settings-item-autosave-description", comment: "when exiting game"),
                    type: Settings.CellType.Toggle),
                Settings.Cell(
                    key: Settings.loadLastSaveKey,
                    title: NSLocalizedString("settings-item-load-last", comment: "Load last save"),
                    description: NSLocalizedString("settings-item-load-last-description", comment: "when starting game"),
                    type: Settings.CellType.Toggle),
                Settings.Cell(
                    key: Settings.saveDataExistsKey,
                    title: NSLocalizedString("settings-item-reset-save-data", comment: "Reset save data"),
                    description: NSLocalizedString("settings-item-reset-save-data-button", comment: "Reset"),
                    metadata: { do { try CoreDataController.removeAllConsoleStates() } catch { } },
                    type: Settings.CellType.Confirmation),
                ]
            ),
        Settings.Section(
            sectionName: NSLocalizedString("settings-section-video", comment: "Video"),
            cells: [
                Settings.Cell(
                    key: Settings.nearestNeighborRenderingKey,
                    title: NSLocalizedString("settings-item-nearest-neighbor", comment: "Nearest neighbor"),
                    description: NSLocalizedString("settings-item-nearest-neighbor-description", comment: "interpolation for sharper edges"),
                    type: Settings.CellType.Toggle),
                Settings.Cell(
                    key: Settings.integerScalingKey,
                    title: NSLocalizedString("settings-item-integer-scaling", comment: "Integer scaling"),
                    description: NSLocalizedString("settings-item-integer-scaling-description", comment: "to exact multiple of 256 × 224"),
                    type: Settings.CellType.Toggle),
                Settings.Cell(
                    key: Settings.checkForRedundantFramesKey,
                    title: NSLocalizedString("settings-item-check-for-duplicate-frames", comment: "Skip duplicate frames"),
                    description: NSLocalizedString("settings-item-check-for-duplicate-frames-description", comment: ""),
                    type: Settings.CellType.Toggle),
                Settings.Cell(
                    key: Settings.scanlinesKey,
                    title: NSLocalizedString("settings-item-scanlines", comment: "Scanlines"),
                    description: nil,
                    metadata: Scanlines.allCases,
                    type: Settings.CellType.Segmented),
                ]
            ),
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
            ),
        Settings.Section(
            sectionName: NSLocalizedString("settings-section-about", comment: "About"),
            cells: [
                Settings.Cell(
                    key: nil,
                    title: NSLocalizedString("settings-item-license", comment: "License"),
                    metadata: [
                        Settings.HelpEntry(header: NSLocalizedString("settings-item-info-license-header", comment: "MIT License"), description: NSLocalizedString("settings-item-info-license-description", comment: "MIT License\n\nCopyright (c) 2020 Tom Salvo\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\n\n The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."), iconNames: nil)
                    ],
                    type: Settings.CellType.Info),
                Settings.Cell(
                    key: nil,
                    title: Bundle.main.friendlyAppNameVersionBuildString,
                    description: "\u{00a9} " + Date().year + " Tom Salvo",
                    type: Settings.CellType.About),
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
        self.tableView.register(UINib.init(nibName: SettingsConfirmationCell.reuseIdentifier, bundle: nil), forCellReuseIdentifier: SettingsConfirmationCell.reuseIdentifier)
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
            
        case .Confirmation:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsConfirmationCell.reuseIdentifier) as! SettingsConfirmationCell
            cell.settingText = cellData.title ?? ""
            cell.buttonText = cellData.description
            cell.settingKey = cellData.key
            cell.confirmationBlock = cellData.metadata as? (() -> Void)
            cell.confirmationDelegate = self
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
    
    // MARK: - SettingsConfirmationDelegate
    
    func confirmationButtonPressed(forKey aKey: String, message aMessage: String, confirmationBlock aConfirmationBlock: (() -> Void)?)
    {
        let alertController = UIAlertController(title: nil, message: aMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction.init(title: NSLocalizedString("button-ok", comment: "OK"), style: .destructive, handler: { _ in
            aConfirmationBlock?()
        }))
        alertController.addAction(UIAlertAction.init(title: NSLocalizedString("button-cancel", comment: "Cancel"), style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
}
