//
//  SceneDelegate.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/14/20.
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

import Foundation

import UIKit
import os

class SceneDelegate: UIResponder, UIWindowSceneDelegate
{
    var window: UIWindow?
    
    weak var documentDelegate: NesRomControllerProtocol?
    
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity?
    {
        return scene.userActivity
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)
    {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }
    
    func sceneDidDisconnect(_ scene: UIScene)
    {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
        (((scene as? UIWindowScene)?.windows.first?.rootViewController?.presentedViewController) as? NesRomControllerProtocol)?.closeDueToExternalChange(completionHandler: nil)
    }
    
    func sceneDidEnterBackground(_ scene: UIScene)
    {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information to restore the scene back to its current state.
        guard let ws = (scene as? UIWindowScene) else { return } // TODO: stop playback and save restoration state
        let _ = ws.windows.first?.rootViewController
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>)
    {
        // Ensure the URL is a file URL
        // Reveal / import the document at the URL
        guard let inputURL = URLContexts.first?.url,
            inputURL.isFileURL,
            let documentBrowserViewController = self.window?.rootViewController as? DocumentBrowserViewController else { return }

        documentBrowserViewController.revealDocument(at: inputURL, importIfNeeded: true) { (revealedDocumentURL, error) in

            if let safeError = error
            {
                // Handle the error appropriately
                os_log(OSLogType.error, "Failed to reveal the document at URL: %@ with error: %@", inputURL.absoluteString, safeError.localizedDescription)
                return
            }

            guard let safeRevealedDocumentURL = revealedDocumentURL else
            {
                return
            }

            scene.title = safeRevealedDocumentURL.lastPathComponent
        }
    }
}
