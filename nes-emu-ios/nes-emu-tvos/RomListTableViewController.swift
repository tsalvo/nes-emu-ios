//
//  RomListTableViewController.swift
//  nes-emu-tvos
//
//  Created by Tom Salvo on 6/26/20.
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
import os

final class RomListTableViewController: UITableViewController
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
