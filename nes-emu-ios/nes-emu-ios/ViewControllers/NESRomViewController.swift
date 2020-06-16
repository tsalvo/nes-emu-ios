//
//  NESRomViewController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/8/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit
import GameController

protocol NesRomControllerDelegate: class
{
    var document: NesRomDocument? { get }
    func closeDueToExternalChange(completionHandler aCompletionHandler: ((Bool) -> Void)?)
}

class NESRomViewController: UIViewController, NesRomControllerDelegate
{
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
    
    var controller: GCController?
    var document: NesRomDocument?
    var console: Console?
    private var displayLink: CADisplayLink?
    private var audioEngine: AudioEngine = AudioEngine()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.controller = GCController.controllers().first
        if let safeCartridge = self.document?.cartridge
        {
            self.console = Console(withCartridge: safeCartridge, sampleRate: SampleRate._22050Hz)
            self.console?.set(audioEngineDelegate: self.audioEngine)
            self.console?.reset(completionHandler: { [weak self] in
                self?.screen.buffer = self?.console?.ppu.frontBuffer ?? []
            })
        }
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        self.createDisplayLink()
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        self.destroyDisplayLink()
    }
    
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
    
    @objc private func updateFrame()
    {
        if let extendedPad = self.controller?.extendedGamepad
        {
            self.console?.set(buttonUpPressed: extendedPad.dpad.up.isPressed, buttonDownPressed: extendedPad.dpad.down.isPressed, buttonLeftPressed: extendedPad.dpad.left.isPressed, buttonRightPressed: extendedPad.dpad.right.isPressed, buttonSelectPressed: extendedPad.buttonOptions?.isPressed ?? extendedPad.buttonY.isPressed, buttonStartPressed: extendedPad.buttonMenu.isPressed, buttonBPressed: extendedPad.buttonX.isPressed, buttonAPressed: extendedPad.buttonA.isPressed, forControllerAtIndex: 0)
        }
        
        self.console?.stepSeconds(seconds: 1.0 / 60.0, completionHandler: { [weak self] in
            self?.screen.buffer = self?.console?.ppu.frontBuffer ?? []
        })
    }
    
    func closeDueToExternalChange(completionHandler aCompletionHandler: ((Bool) -> Void)?)
    {
        if !self.isBeingDismissed
        {
            self.destroyDisplayLink()
            self.dismiss(animated: true, completion: { [weak self] in
                if let safeDocument = self?.document
                {
                    safeDocument.close(completionHandler: { (success) in
                        aCompletionHandler?(success)
                    })
                }
                else
                {
                    aCompletionHandler?(true)
                }
            })
        }
        else
        {
            aCompletionHandler?(true)
        }
    }
    
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
    
    
}
