//
//  NesRomNavigationController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/19/20.
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

protocol NesRomNavigationControllerProtocol: class
{
    var document: NesRomDocument? { get set }
    func pauseEmulation()
    func closeDueToExternalChange(completionHandler aCompletionHandler: ((Bool) -> Void)?)
}

class NesRomNavigationController: UINavigationController, NesRomNavigationControllerProtocol
{
    var document: NesRomDocument?
    
    func pauseEmulation()
    {
        (self.viewControllers.first as? EmulationControlProtocol)?.pauseEmulation()
    }
    
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
