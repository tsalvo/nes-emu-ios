//
//  DocumentBrowserViewController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/4/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit
//import SwiftUI

class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate
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
        
        self.delegate = self
        
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
        
        if let safeRomController = self.presentedViewController as? NesRomControllerDelegate
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
        if let safeRomVC = segue.destination as? NESRomViewController,
            let document = sender as? NesRomDocument
        {
            safeRomVC.document = document
        }
    }

    func closeDocument(_ document: NesRomDocument)
    {
        self.dismiss(animated: true, completion: {
            document.close(completionHandler: nil)
        })
    }
}
