//
//  DocumentBrowserViewController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/4/20.
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

class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate, UIPopoverPresentationControllerDelegate
{
    
#if targetEnvironment(macCatalyst)
    static let segueForNesRom: String = "playROMCrossDissolve"
#else
    static let segueForNesRom: String = "playROM"
#endif
    
    // MARK: - Life Cycle
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.additionalTrailingNavigationBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(settingsButtonPressed(_:)))]
        self.delegate = self
        self.view.tintColor = UIColor.systemRed
        self.allowsDocumentCreation = false
        self.allowsPickingMultipleItems = false
    }
    
    
    // MARK: UIDocumentBrowserViewControllerDelegate
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL])
    {
        guard let sourceURL = documentURLs.first else { return }
        
        // Present the Document View Controller for the first document that was picked.
        // If you support picking multiple items, make sure you handle them all.
        self.presentDocument(at: sourceURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL)
    {
        // Present the Document View Controller for the new newly created document
        self.presentDocument(at: destinationURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?)
    {
        let alertVC = UIAlertController(title: NSLocalizedString("title-error", comment: "Error"), message: NSLocalizedString("error-failed-to-import-document", comment: "Failed to import document"), preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: NSLocalizedString("button-ok", comment: "OK"), style: .cancel, handler: nil))
        self.present(alertVC, animated: true, completion: nil)
    }
    
    // MARK: - UIPopoverPresentationControllerDelegate
    
    func prepareForPopoverPresentation(_ popoverPresentationController: UIPopoverPresentationController)
    {
        popoverPresentationController.backgroundColor = UIColor.systemBackground
        popoverPresentationController.canOverlapSourceViewRect = true
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle
    {
        return UIModalPresentationStyle.none
    }
    
    // MARK: - Document Presentation
    
    func presentDocument(at documentURL: URL)
    {
        func present(document aDocument: UIDocument)
        {
            // Access the document
            document.open(completionHandler: { success in
                if success
                {
                    self.performSegue(withIdentifier: DocumentBrowserViewController.segueForNesRom, sender: document)
                }
            })
        }
        
        let document = NesRomDocument(fileURL: documentURL)
        
        if let safeRomController = self.presentedViewController as? NesRomNavigationControllerProtocol
        {
            safeRomController.closeDueToExternalChange(completionHandler: { (success) in
                present(document: document)
            })
        }
        else
        {
            present(document: document)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if let safeRomVC = segue.destination as? NesRomNavigationControllerProtocol,
            let document = sender as? NesRomDocument
        {
            safeRomVC.document = document
        }
        else if let settingsVC = segue.destination as? SettingsNavigationController
        {
            settingsVC.modalPresentationStyle = UIModalPresentationStyle.popover
            settingsVC.popoverPresentationController?.delegate = self
            settingsVC.popoverPresentationController?.barButtonItem = self.additionalTrailingNavigationBarButtonItems.first
        }
    }

    func closeDocument(_ document: NesRomDocument)
    {
        self.dismiss(animated: true, completion: {
            document.close(completionHandler: nil)
        })
    }
    
    @objc private func settingsButtonPressed(_ sender: AnyObject?)
    {
        self.performSegue(withIdentifier: "showSettingsFromDocumentBrowser", sender: nil)
    }
}
