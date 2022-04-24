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

protocol NesRomNavigationControllerProtocol: AnyObject
{
    var document: NesRomDocument? { get set }
    func pauseEmulation()
    func closeDueToExternalChange(completionHandler aCompletionHandler: ((Bool) -> Void)?)
}

final class NesRomNavigationController: UINavigationController, NesRomNavigationControllerProtocol
{
    var document: NesRomDocument?
    
    override func viewDidLoad()
    {
        if let safeCartridge = self.document?.cartridge,
            let safeEmulatorVC = self.viewControllers.first as? EmulatorProtocol
        {
            safeEmulatorVC.cartridge = safeCartridge
        }
        
        // close right away because we don't need the document anymore
        self.document?.close(completionHandler: { [weak self] (_) in
            self?.document = nil
        })
    }
    
    func pauseEmulation()
    {
        (self.viewControllers.first as? EmulatorProtocol)?.pauseEmulation()
    }
    
    func closeDueToExternalChange(completionHandler aCompletionHandler: ((Bool) -> Void)?)
    {
        if !self.isBeingDismissed
        {
            self.dismiss(animated: true, completion: {
                aCompletionHandler?(true)
            })
        }
        else
        {
            aCompletionHandler?(true)
        }
    }
}
