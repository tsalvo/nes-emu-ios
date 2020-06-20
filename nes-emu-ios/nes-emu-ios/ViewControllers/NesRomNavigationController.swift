//
//  NesRomNavigationController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/19/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit

protocol NesRomControllerProtocol: class
{
    var document: NesRomDocument? { get set }
    func closeDueToExternalChange(completionHandler aCompletionHandler: ((Bool) -> Void)?)
}

class NesRomNavigationController: UINavigationController, NesRomControllerProtocol
{
    var document: NesRomDocument?
    
    func closeDueToExternalChange(completionHandler aCompletionHandler: ((Bool) -> Void)?)
    {
        func closeIfNeeded(completionHandler aCompletionHandler: ((Bool) -> Void)?)
        {
            if let safeDocument = self.document
            {
                safeDocument.close(completionHandler: { (success) in
                    aCompletionHandler?(success)
                })
            }
            else
            {
                aCompletionHandler?(true)
            }
        }
        
        if !self.isBeingDismissed
        {
            self.dismiss(animated: true, completion: {
                closeIfNeeded(completionHandler: aCompletionHandler)
            })
        }
        else
        {
            closeIfNeeded(completionHandler: aCompletionHandler)
        }
    }
}
