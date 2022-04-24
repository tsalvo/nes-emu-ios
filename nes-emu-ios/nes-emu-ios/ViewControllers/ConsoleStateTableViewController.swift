//
//  SaveStateTableViewController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
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

final class ConsoleStateTableViewController: UITableViewController
{
    var md5: String?
    weak var consoleSaveStateSelectionDelegate: ConsoleSaveStateSelectionDelegate?

    private var observation: NSKeyValueObservation?
    private var consoleStates: [ConsoleState]?
    {
        didSet
        {
            if oldValue == nil
            {
                self.tableView.reloadData()
            }
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        if let safeMD5 = self.md5 {
            self.consoleStates = try? CoreDataController.consoleStates(forMD5: safeMD5)
        }
        
        let symbolConfig = UIImage.SymbolConfiguration.init(pointSize: 21.0, weight: .semibold)
        
#if targetEnvironment(macCatalyst)
        let closeButtonName: String = "xmark"
#else
        let closeButtonName: String = "chevron.down"
#endif
        
        let closeButton: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: closeButtonName, withConfiguration: symbolConfig), style: .plain, target: self, action: #selector(dismissButtonPressed(_:)))
        
        self.navigationItem.setRightBarButton(closeButton, animated: false)
    
        self.observation = self.tableView.observe(\.contentSize) { [weak self] (t, _) in
            self?.navigationController?.preferredContentSize = CGSize(width: 320, height: t.contentSize.height)
        }
        self.popoverPresentationController?.backgroundColor = UIColor.systemBackground
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.register(UINib.init(nibName: ConsoleStateCell.reuseIdentifier, bundle: nil), forCellReuseIdentifier: ConsoleStateCell.reuseIdentifier)
        self.tableView.register(UINib.init(nibName: AddConsoleStateCell.reuseIdentifier, bundle: nil), forCellReuseIdentifier: AddConsoleStateCell.reuseIdentifier)
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        self.consoleSaveStateSelectionDelegate?.consoleStateSelectionDismissed()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        switch section
        {
        case 0: return 1
        case 1: return (self.consoleStates ?? []).count
        default: return 0
        }
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        switch indexPath.section
        {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: AddConsoleStateCell.reuseIdentifier) as! AddConsoleStateCell
            cell.saveStateText = NSLocalizedString("label-new-save-state", comment: "New Save")
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: ConsoleStateCell.reuseIdentifier) as! ConsoleStateCell
            cell.date = self.consoleStates?[indexPath.row].date
            cell.buffer = self.consoleStates?[indexPath.row].ppuState.frontBuffer
            cell.isAutosave = self.consoleStates?[indexPath.row].isAutoSave ?? false
            return cell
        default: return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        switch indexPath.section
        {
        case 0:
            self.consoleSaveStateSelectionDelegate?.saveCurrentStateSelected()
        case 1:
            if let safeSaveState: ConsoleState = self.consoleStates?[indexPath.row]
            {
                self.consoleSaveStateSelectionDelegate?.consoleStateSelected(consoleState: safeSaveState)
            }
        default: break
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    {
        // Return false if you do not want the specified item to be editable.
        switch indexPath.section
        {
        case 0: return false
        case 1: return true
        default: return false
        }
    }
    

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        guard let safeConsoleState = self.consoleStates?[indexPath.row],
            editingStyle == .delete
        else
        {
            return
        }
        
        do
        {
            try CoreDataController.removeConsoleState(forMD5: safeConsoleState.md5, date: safeConsoleState.date)
            self.consoleStates?.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
        catch
        {
            let alertVC = UIAlertController.init(title: NSLocalizedString("title-error", comment: "Error"), message: NSLocalizedString("error-failed-to-delete-save-state", comment: "Failed to delete save state"), preferredStyle: .alert)
            alertVC.addAction(UIAlertAction.init(title: NSLocalizedString("button-ok", comment: "OK"), style: .cancel, handler: nil))
            self.present(alertVC, animated: true, completion: nil)
        }
    }
    
    // MARK: - Button Actions
    
    @IBAction private func dismissButtonPressed(_ sender: AnyObject?)
    {
        self.dismiss(animated: true, completion: nil)
    }
}
