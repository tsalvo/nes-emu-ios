//
//  ConsoleStateNavigationController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/15/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit

class ConsoleStateNavigationController: UINavigationController
{
    var md5: String?
    weak var consoleSaveStateSelectionDelegate: ConsoleSaveStateSelectionDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let safeConsoleStateVC = self.viewControllers.first as? ConsoleStateTableViewController
        {
            safeConsoleStateVC.md5 = self.md5
            safeConsoleStateVC.consoleSaveStateSelectionDelegate = self.consoleSaveStateSelectionDelegate
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
