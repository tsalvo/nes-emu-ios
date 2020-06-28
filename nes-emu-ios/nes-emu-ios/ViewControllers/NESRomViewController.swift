//
//  NesRomViewController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/8/20.
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
import GameController

protocol EmulatorProtocol: class
{
    var cartridge: Cartridge? { get set }
    func pauseEmulation()
}

class NesRomViewController: GCEventViewController, EmulatorProtocol
{
    // MARK: - Constants
    private static let defaultFrameQueueSize: Int = 5
    
    // MARK: - UI Outlets
    @IBOutlet weak private var screen: NESScreenView!
#if !os(tvOS)
    @IBOutlet weak private var aButton: UIButton!
    @IBOutlet weak private var bButton: UIButton!
    @IBOutlet weak private var upButton: UIButton!
    @IBOutlet weak private var downButton: UIButton!
    @IBOutlet weak private var leftButton: UIButton!
    @IBOutlet weak private var rightButton: UIButton!
    @IBOutlet weak private var selectButton: UIButton!
    @IBOutlet weak private var startButton: UIButton!
#endif
    
    // MARK: - Private Variables
    private weak var dismissBarButtonItem: UIBarButtonItem?
    private weak var resetBarButtonItem: UIBarButtonItem?
    private weak var controller1BarButtonItem: UIBarButtonItem?
    private weak var controller2BarButtonItem: UIBarButtonItem?
    
    private var consoleFrameQueueSize: Int = NesRomViewController.defaultFrameQueueSize
    private var consoleFramesQueued: Int = 0
    var cartridge: Cartridge?
    {
        didSet
        {
            guard let safeCartridge = self.cartridge else { return }
            let sampleRate: SampleRate = SampleRate.init(rawValue: UserDefaults.standard.integer(forKey: Settings.sampleRateKey)) ?? Settings.defaultSampleRate
            let audioFiltersEnabled: Bool = UserDefaults.standard.bool(forKey: Settings.audioFiltersEnabledKey)
            self.consoleQueue.async { [weak self] in
                self?.console = Console(withCartridge: safeCartridge, sampleRate: sampleRate, audioFiltersEnabled: audioFiltersEnabled)
                self?.console?.set(audioEngineDelegate: self?.audioEngine)
                self?.console?.reset()
            }
        }
    }
    private let consoleQueue: DispatchQueue = DispatchQueue(label: "ConsoleQueue", qos: .userInteractive)
    
    private var controller1: GCController?
    {
        didSet
        {
            self.controller1BarButtonItem?.isEnabled = !(self.controller1?.extendedGamepad == nil)
#if targetEnvironment(macCatalyst)
            self.setOnScreenControlsHidden(true, animated: false)
#else
            self.setOnScreenControlsHidden(self.controller1?.extendedGamepad != nil, animated: true)
#endif
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
            self.controller2BarButtonItem?.isEnabled = !(self.controller2?.extendedGamepad == nil)
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
        self.controllerUserInteractionEnabled = false
        self.consoleFrameQueueSize = NesRomViewController.defaultFrameQueueSize
        self.setupButtons()
#if os(tvOS)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
#endif
#if targetEnvironment(macCatalyst)
        self.setOnScreenControlsHidden(true, animated: false)
#elseif targetEnvironment(simulator)
        self.setOnScreenControlsHidden(false, animated: false)
#endif
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.becomeFirstResponder()
        self.checkForControllers()
        NotificationCenter.default.addObserver(self, selector: #selector(handleControllerConnect(_:)), name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleControllerDisconnect(_:)), name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
        UIApplication.shared.isIdleTimerDisabled = true
        self.createDisplayLink()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        self.destroyDisplayLink()
        self.resignFirstResponder()
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    // MARK: EmulatorProtocol
    func pauseEmulation()
    {
        self.consoleFrameQueueSize = 0
        self.destroyDisplayLink()
    }
    
    // MARK: - Button Actions
    @objc private func dismissButtonPressed(_ sender: AnyObject?)
    {
        if !self.isBeingDismissed
        {
            self.destroyDisplayLink()
#if os(tvOS)
            self.navigationController?.popViewController(animated: true)
#else
            self.dismiss(animated: true, completion: nil)
#endif
        }
    }
    
    @objc private func resetButtonPressed(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.reset()
            DispatchQueue.main.async {
                self?.screen.buffer = PPU.emptyBuffer
            }
        }
    }
    
    @IBAction private func startButtonPressed(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonStart, enabled: true, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func startButtonReleased(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonStart, enabled: false, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func selectButtonPressed(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonSelect, enabled: true, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func selectButtonReleased(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonSelect, enabled: false, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func aButtonPressed(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonA, enabled: true, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func aButtonReleased(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonA, enabled: false, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func bButtonPressed(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonB, enabled: true, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func bButtonReleased(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonB, enabled: false, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func upButtonPressed(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonUp, enabled: true, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func upButtonReleased(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonUp, enabled: false, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func downButtonPressed(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonDown, enabled: true, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func downButtonReleased(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonDown, enabled: false, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func leftButtonPressed(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonLeft, enabled: true, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func leftButtonReleased(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonLeft, enabled: false, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func rightButtonPressed(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonRight, enabled: true, forControllerAtIndex: 0)
        }
    }
    
    @IBAction private func rightButtonReleased(_ sender: AnyObject?)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.set(button: .buttonRight, enabled: false, forControllerAtIndex: 0)
        }
    }
    
    // MARK: - Keyboard
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {

        var didHandleEvent = false
        for press in presses
        {
            guard let keyCommand = press.key?.charactersIgnoringModifiers else { continue }
            switch keyCommand
            {
            case UIKeyCommand.inputUpArrow:
                self.upButtonPressed(nil)
                didHandleEvent = true
            case UIKeyCommand.inputDownArrow:
                self.downButtonPressed(nil)
                didHandleEvent = true
            case UIKeyCommand.inputLeftArrow:
                self.leftButtonPressed(nil)
                didHandleEvent = true
            case UIKeyCommand.inputRightArrow:
                self.rightButtonPressed(nil)
                didHandleEvent = true
            case "a":
                self.selectButtonPressed(nil)
                didHandleEvent = true
            case "s":
                self.startButtonPressed(nil)
                didHandleEvent = true
            case "z":
                self.bButtonPressed(nil)
                didHandleEvent = true
            case "x":
                self.aButtonPressed(nil)
                didHandleEvent = true
            default:
                break
            }
        }
        
        if didHandleEvent == false
        {
            // Didn't handle this key press, so pass the event to the next responder.
            super.pressesBegan(presses, with: event)
        }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Stop running when the user releases the left or right arrow key.

        var didHandleEvent = false
        for press in presses
        {
            guard let keyCommand = press.key?.charactersIgnoringModifiers else { continue }
            
            switch keyCommand
            {
            case UIKeyCommand.inputUpArrow:
                self.upButtonReleased(nil)
                didHandleEvent = true
            case UIKeyCommand.inputDownArrow:
                self.downButtonReleased(nil)
                didHandleEvent = true
            case UIKeyCommand.inputLeftArrow:
                self.leftButtonReleased(nil)
                didHandleEvent = true
            case UIKeyCommand.inputRightArrow:
                self.rightButtonReleased(nil)
                didHandleEvent = true
            case "a":
                self.selectButtonReleased(nil)
                didHandleEvent = true
            case "s":
                self.startButtonReleased(nil)
                didHandleEvent = true
            case "z":
                self.bButtonReleased(nil)
                didHandleEvent = true
            case "x":
                self.aButtonReleased(nil)
                didHandleEvent = true
            default:
                break
            }
        }
        
        if didHandleEvent == false
        {
            // Didn't handle this key press, so pass the event to the next responder.
            super.pressesBegan(presses, with: event)
        }
    }
    
    // MARK - Display Link Frame Update
    @objc private func updateFrame()
    {
        if let extendedPad = self.controller1?.capture().extendedGamepad
        {
            self.consoleQueue.async { [weak self] in
                self?.console?.set(buttonUpPressed: extendedPad.dpad.up.isPressed, buttonDownPressed: extendedPad.dpad.down.isPressed, buttonLeftPressed: extendedPad.dpad.left.isPressed, buttonRightPressed: extendedPad.dpad.right.isPressed, buttonSelectPressed: extendedPad.buttonOptions?.isPressed ?? extendedPad.buttonY.isPressed, buttonStartPressed: extendedPad.buttonMenu.isPressed, buttonBPressed: extendedPad.buttonX.isPressed, buttonAPressed: extendedPad.buttonA.isPressed, forControllerAtIndex: 0)
            }
            
            if (extendedPad.leftThumbstickButton ?? extendedPad.leftTrigger).isPressed && (extendedPad.rightThumbstickButton ?? extendedPad.rightTrigger).isPressed
            {
                self.pauseEmulation()
                self.dismissButtonPressed(nil)
                return
            }
        }
        
        if let extendedPad = self.controller2?.capture().extendedGamepad
        {
            self.consoleQueue.async { [weak self] in
                self?.console?.set(buttonUpPressed: extendedPad.dpad.up.isPressed, buttonDownPressed: extendedPad.dpad.down.isPressed, buttonLeftPressed: extendedPad.dpad.left.isPressed, buttonRightPressed: extendedPad.dpad.right.isPressed, buttonSelectPressed: extendedPad.buttonOptions?.isPressed ?? extendedPad.buttonY.isPressed, buttonStartPressed: extendedPad.buttonMenu.isPressed, buttonBPressed: extendedPad.buttonX.isPressed, buttonAPressed: extendedPad.buttonA.isPressed, forControllerAtIndex: 1)
            }
            
            if (extendedPad.leftThumbstickButton ?? extendedPad.leftTrigger).isPressed && (extendedPad.rightThumbstickButton ?? extendedPad.rightTrigger).isPressed
            {
                self.pauseEmulation()
                self.dismissButtonPressed(nil)
                return
            }
        }
        
        guard self.consoleFramesQueued <= self.consoleFrameQueueSize else { return }
        self.consoleFramesQueued += 1
        
        self.consoleQueue.async { [weak self] in
            self?.console?.stepSeconds(seconds: 1.0 / 60.0)
            DispatchQueue.main.async { [weak self] in
                self?.consoleFramesQueued -= 1
                self?.screen.buffer = self?.console?.screenBuffer ?? PPU.emptyBuffer
            }
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
        
        safeController.playerIndex = .indexUnset
        
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
#if targetEnvironment(simulator)
#else
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
#endif
    }
    
    private func setOnScreenControlsHidden(_ hidden: Bool, animated aAnimated: Bool)
    {
#if !os(tvOS)
        let buttons: [UIButton] = [self.aButton, self.bButton, self.upButton, self.downButton, self.leftButton, self.rightButton, self.selectButton, self.startButton]
        
        guard aAnimated else
        {
            for b in buttons
            {
                b.alpha = hidden ? 0.0 : 1.0
                b.isHidden = false
            }
            return
        }
        
        if !hidden
        {
            for b in buttons
            {
                b.alpha = 0.0
                b.isHidden = false
            }
        }
        
        UIView.animate(withDuration: 0.33, animations: {
            for b in buttons
            {
                b.alpha = hidden ? 0.0 : 1.0
            }
        }) { _ in
            for b in buttons
            {
                b.isHidden = hidden
            }
        }
#endif
    }
    
    private func setupButtons()
    {
#if targetEnvironment(macCatalyst)
        let symbolConfig = UIImage.SymbolConfiguration.init(pointSize: 24.0, weight: .semibold)
#else
        let symbolConfig = UIImage.SymbolConfiguration.init(pointSize: 21.0, weight: .semibold)
#endif
            
        let resetButton: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "power", withConfiguration: symbolConfig), style: .plain, target: self, action: #selector(resetButtonPressed(_:)))
        let controller1Button: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gamecontroller", withConfiguration: symbolConfig), style: .plain, target: self, action: nil)
        let controller2Button: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gamecontroller", withConfiguration: symbolConfig), style: .plain, target: self, action: nil)
        let closeButton: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark", withConfiguration: symbolConfig), style: .plain, target: self, action: #selector(dismissButtonPressed(_:)))
        controller1Button.isEnabled = false
        controller2Button.isEnabled = false
        
        self.resetBarButtonItem = resetButton
        self.controller1BarButtonItem = controller1Button
        self.controller2BarButtonItem = controller2Button
        self.dismissBarButtonItem = closeButton
           
        self.navigationItem.setLeftBarButtonItems([resetButton, controller1Button, controller2Button], animated: false)
        
#if targetEnvironment(macCatalyst)
#else
        self.navigationItem.setRightBarButtonItems([closeButton], animated: false)
#endif
    }
}
