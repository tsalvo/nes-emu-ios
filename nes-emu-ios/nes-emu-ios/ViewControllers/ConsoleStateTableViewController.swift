//
//  SaveStateTableViewController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit

class ConsoleStateTableViewController: UITableViewController
{
    var md5: String?
    weak var consoleSaveStateSelectionDelegate: ConsoleSaveStateSelectionDelegate?
    private var observation: NSKeyValueObservation?
    private var consoleStates: [ConsoleState]?
    {
        didSet
        {
            self.tableView.reloadData()
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        if let safeMD5 = self.md5 {
            self.consoleStates = try? CoreDataController.consoleStates(forMD5: safeMD5)
        }
    
        self.observation = self.tableView.observe(\.contentSize) { [weak self] (t, _) in
            self?.navigationController?.preferredContentSize = CGSize(width: 320, height: t.contentSize.height)
        }
        self.popoverPresentationController?.backgroundColor = UIColor.systemBackground
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.register(UINib.init(nibName: ConsoleStateCell.reuseIdentifier, bundle: nil), forCellReuseIdentifier: ConsoleStateCell.reuseIdentifier)
        self.tableView.register(UINib.init(nibName: AddConsoleStateCell.reuseIdentifier, bundle: nil), forCellReuseIdentifier: AddConsoleStateCell.reuseIdentifier)
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
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
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
