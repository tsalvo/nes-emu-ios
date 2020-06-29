//
//  RomListTableViewController.swift
//  nes-emu-tvos
//
//  Created by Tom Salvo on 6/26/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit
import os

struct TestROM
{
    var title: String
    var data: [UInt8]
}

class RomListTableViewController: UITableViewController
{
    var romURLs: [URL] = []
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        let urls = Bundle.main.urls(forResourcesWithExtension: "nes", subdirectory: nil)
        for url in urls ?? []
        {
            self.romURLs.append(url)
        }
        
        self.romURLs.sort(by: { $0.lastPathComponent < $1.lastPathComponent })
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.romURLs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let tableViewCell = UITableViewCell.init(style: .default, reuseIdentifier: "TableViewCell")
        tableViewCell.textLabel?.text = self.romURLs[indexPath.row].lastPathComponent
        return tableViewCell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        self.performSegue(withIdentifier: "playROM", sender: indexPath)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if let safeRomVC = segue.destination as? NesRomViewController,
            let safeIndex = (sender as? IndexPath)?.row
        {
            do
            {
                let data = try Data.init(contentsOf: self.romURLs[safeIndex], options: Data.ReadingOptions.uncached)
                safeRomVC.cartridge = Cartridge.init(fromData: Data(data))
            }
            catch
            {
                os_log("Error loading ROM from Bundle Resources")
            }
        }
    }
}
