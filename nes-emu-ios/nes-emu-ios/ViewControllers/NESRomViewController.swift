//
//  NESRomViewController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/8/20.
//  Copyright © 2020 Tom Salvo.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit
import GameController

protocol NesRomControllerDelegate: class
{
    var document: NesRomDocument? { get }
    func closeDueToExternalChange(completionHandler aCompletionHandler: ((Bool) -> Void)?)
}

class NESRomViewController: UIViewController, NesRomControllerDelegate
{
    // MARk: - UI Outlets
    @IBOutlet weak private var screen: NESScreenView!
    @IBOutlet weak private var dismissButton: UIButton!
    @IBOutlet weak private var resetButton: UIButton!
    @IBOutlet weak private var aButton: UIButton!
    @IBOutlet weak private var bButton: UIButton!
    @IBOutlet weak private var upButton: UIButton!
    @IBOutlet weak private var downButton: UIButton!
    @IBOutlet weak private var leftButton: UIButton!
    @IBOutlet weak private var rightButton: UIButton!
    @IBOutlet weak private var selectButton: UIButton!
    @IBOutlet weak private var startButton: UIButton!
    
    // MARK: - Public Variables
    var document: NesRomDocument?
    
    // MARK: - Private Variables
    private var controller1: GCController?
    {
        didSet
        {
            self.setOnScreenControlsHidden(self.controller1?.extendedGamepad != nil)
            if self.controller1 == nil
            {
                self.console?.set(buttonUpPressed: false, buttonDownPressed: false, buttonLeftPressed: false, buttonRightPressed: false, buttonSelectPressed: false, buttonStartPressed: false, buttonBPressed: false, buttonAPressed: false, forControllerAtIndex: 0)
            }
        }
    }
    
    private var controller2: GCController?
    {
        didSet
        {
            if self.controller2 == nil
            {
                self.console?.set(buttonUpPressed: false, buttonDownPressed: false, buttonLeftPressed: false, buttonRightPressed: false, buttonSelectPressed: false, buttonStartPressed: false, buttonBPressed: false, buttonAPressed: false, forControllerAtIndex: 1)
            }
        }
    }
    
    private var console: Console?
    private var displayLink: CADisplayLink?
    private var audioEngine: AudioEngine = AudioEngine()
    
    // MARK: - UIViewController Life Cycle
    override func viewDidLoad()
    {
        super.viewDidLoad()
        if let safeCartridge = self.document?.cartridge
        {
            self.console = Console(withCartridge: safeCartridge, sampleRate: SampleRate._22050Hz)
            self.console?.set(audioEngineDelegate: self.audioEngine)
            self.console?.reset(completionHandler: { [weak self] in
                self?.screen.buffer = self?.console?.ppu.frontBuffer ?? []
            })
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.checkForControllers()
        NotificationCenter.default.addObserver(self, selector: #selector(handleControllerConnect(_:)), name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleControllerDisconnect(_:)), name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
        UIApplication.shared.isIdleTimerDisabled = true
        self.createDisplayLink()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.isIdleTimerDisabled = false
        self.destroyDisplayLink()
    }
    
    
    // MARK: - Button Actions
    @IBAction private func dismiss(_ sender: AnyObject?)
    {
        if !self.isBeingDismissed
        {
            self.destroyDisplayLink()
            self.dismiss(animated: true, completion: { [weak self] in
                self?.document?.close(completionHandler: nil)
            })
        }
    }
    
    @IBAction private func reset(_ sender: AnyObject?)
    {
        self.console?.reset(completionHandler: { [weak self] in
            self?.screen.buffer = self?.console?.ppu.frontBuffer ?? []
        })
    }
    
    @IBAction private func startButtonPressed(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonStart, enabled: true, forControllerAtIndex: 0)
    }
    
    @IBAction private func startButtonReleased(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonStart, enabled: false, forControllerAtIndex: 0)
    }
    
    @IBAction private func selectButtonPressed(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonSelect, enabled: true, forControllerAtIndex: 0)
    }
    
    @IBAction private func selectButtonReleased(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonSelect, enabled: false, forControllerAtIndex: 0)
    }
    
    @IBAction private func aButtonPressed(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonA, enabled: true, forControllerAtIndex: 0)
    }
    
    @IBAction private func aButtonReleased(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonA, enabled: false, forControllerAtIndex: 0)
    }
    
    @IBAction private func bButtonPressed(_ sender: AnyObject?)
    {
       self.console?.set(button: .buttonB, enabled: true, forControllerAtIndex: 0)
    }
    
    @IBAction private func bButtonReleased(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonB, enabled: false, forControllerAtIndex: 0)
    }
    
    @IBAction private func upButtonPressed(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonUp, enabled: true, forControllerAtIndex: 0)
    }
    
    @IBAction private func upButtonReleased(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonUp, enabled: false, forControllerAtIndex: 0)
    }
    
    @IBAction private func downButtonPressed(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonDown, enabled: true, forControllerAtIndex: 0)
    }
    
    @IBAction private func downButtonReleased(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonDown, enabled: false, forControllerAtIndex: 0)
    }
    
    @IBAction private func leftButtonPressed(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonLeft, enabled: true, forControllerAtIndex: 0)
    }
    
    @IBAction private func leftButtonReleased(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonLeft, enabled: false, forControllerAtIndex: 0)
    }
    
    @IBAction private func rightButtonPressed(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonRight, enabled: true, forControllerAtIndex: 0)
    }
    
    @IBAction private func rightButtonReleased(_ sender: AnyObject?)
    {
        self.console?.set(button: .buttonRight, enabled: false, forControllerAtIndex: 0)
    }
    
    // MARK - Display Link Frame Update
    @objc private func updateFrame()
    {
        if let extendedPad = self.controller1?.extendedGamepad
        {
            self.console?.set(buttonUpPressed: extendedPad.dpad.up.isPressed, buttonDownPressed: extendedPad.dpad.down.isPressed, buttonLeftPressed: extendedPad.dpad.left.isPressed, buttonRightPressed: extendedPad.dpad.right.isPressed, buttonSelectPressed: extendedPad.buttonOptions?.isPressed ?? extendedPad.buttonY.isPressed, buttonStartPressed: extendedPad.buttonMenu.isPressed, buttonBPressed: extendedPad.buttonX.isPressed, buttonAPressed: extendedPad.buttonA.isPressed, forControllerAtIndex: 0)
        }
        
        if let extendedPad = self.controller2?.extendedGamepad
        {
            self.console?.set(buttonUpPressed: extendedPad.dpad.up.isPressed, buttonDownPressed: extendedPad.dpad.down.isPressed, buttonLeftPressed: extendedPad.dpad.left.isPressed, buttonRightPressed: extendedPad.dpad.right.isPressed, buttonSelectPressed: extendedPad.buttonOptions?.isPressed ?? extendedPad.buttonY.isPressed, buttonStartPressed: extendedPad.buttonMenu.isPressed, buttonBPressed: extendedPad.buttonX.isPressed, buttonAPressed: extendedPad.buttonA.isPressed, forControllerAtIndex: 1)
        }
        
        self.console?.stepSeconds(seconds: 1.0 / 60.0, completionHandler: { [weak self] in
            self?.screen.buffer = self?.console?.ppu.frontBuffer ?? []
        })
    }
    
    // MARK: - NesRomControllerDelegate
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
        
        self.destroyDisplayLink()
        
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
    
    // MARK: - Notifications
    @objc private func handleControllerConnect(_ notification: Notification)
    {
        guard let safeController = notification.object as? GCController
        else
        {
            return
        }
        
        if self.controller1 == nil
        {
            self.controller1 = safeController
        }
        else if self.controller2 == nil
        {
            self.controller2 = safeController
        }
    }
    
    @objc private func handleControllerDisconnect(_ notification: Notification)
    {
        guard let safeController = notification.object as? GCController
        else
        {
            return
        }
        
        if self.controller1 === safeController
        {
            self.controller1 = nil
        }
        else if self.controller2 === safeController
        {
            self.controller2 = nil
        }
    }
    
    // MARK: - Private Functions
    
    private func createDisplayLink()
    {
        self.destroyDisplayLink()
        self.displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        self.displayLink?.preferredFramesPerSecond = 60
        self.displayLink?.add(to: RunLoop.current, forMode: RunLoop.Mode.default)
        self.displayLink?.add(to: RunLoop.current, forMode: RunLoop.Mode.tracking)
    }
    
    private func destroyDisplayLink()
    {
        self.displayLink?.isPaused = true
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
    
    private func checkForControllers()
    {
        let currentControllers: [GCController] = GCController.controllers()
        
        if let safeController1 = self.controller1
        {
            if !currentControllers.contains(safeController1)
            {
                // reassign controller 1 if available
                self.controller1 = nil
                for c in currentControllers
                {
                    if c !== self.controller2
                    {
                        self.controller1 = c
                        break
                    }
                }
            }
        }
        else
        {
            // reassign controller 1 if available
            for c in currentControllers
            {
                if c !== self.controller2
                {
                    self.controller1 = c
                    break
                }
            }
        }
        
        if let safeController2 = self.controller2
        {
            if !currentControllers.contains(safeController2)
            {
                // reassign controller 2 if available
                self.controller2 = nil
                for c in currentControllers
                {
                    if c !== self.controller1
                    {
                        self.controller2 = c
                        break
                    }
                }
            }
        }
        else
        {
            // reassign controller 2 if available
            for c in currentControllers
            {
                if c !== self.controller1
                {
                    self.controller2 = c
                    break
                }
            }
        }
    }
    
    private func setOnScreenControlsHidden(_ hidden: Bool)
    {
        self.aButton.isHidden = hidden
        self.bButton.isHidden = hidden
        self.startButton.isHidden = hidden
        self.selectButton.isHidden = hidden
        self.upButton.isHidden = hidden
        self.downButton.isHidden = hidden
        self.leftButton.isHidden = hidden
        self.rightButton.isHidden = hidden
    }
}
