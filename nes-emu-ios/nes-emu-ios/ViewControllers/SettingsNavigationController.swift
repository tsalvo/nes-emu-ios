//
//  SettingsNavigationController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/20/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit

class SettingsNavigationController: UINavigationController
{
    // MARK: - Life Cycle
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.navigationBar.tintColor = UIColor.init(named: "AppTint")
        self.applyTheme()
    }
    
    // MARK: - Private Functions
    
    private func applyTheme()
    {
        self.navigationBar.barStyle = UIBarStyle.default
        self.navigationBar.isTranslucent = true
        self.popoverPresentationController?.backgroundColor = UIColor.systemBackground
    }
}
