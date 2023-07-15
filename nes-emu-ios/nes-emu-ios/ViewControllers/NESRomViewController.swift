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
import CoreData

protocol EmulatorProtocol: AnyObject
{
    var cartridge: Cartridge? { get set }
    func pauseEmulation()
    func resumeEmulation()
}

protocol ConsoleSaveStateSelectionDelegate: AnyObject
{
    func saveCurrentStateSelected()
    func consoleStateSelected(consoleState aConsoleState: ConsoleState)
    func consoleStateSelectionDismissed()
}

final class NesRomViewController: GCEventViewController, EmulatorProtocol, ConsoleSaveStateSelectionDelegate
{
    // MARK: - Constants
    private static let defaultFrameQueueSize: Int = 3
    private static let analogDeadZoneLeftRight: Float = 0.23
    private static let analogDeadZoneUpDown: Float = 0.3
    
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
    @IBOutlet weak private var screenTapAreaLeadingToButtons: NSLayoutConstraint?
    @IBOutlet weak private var screenTapAreaTrailingToButtons: NSLayoutConstraint?
    @IBOutlet weak private var screenTapAreaBottomToButtons: NSLayoutConstraint?
#endif
    
    // MARK: - Private Variables
    private weak var dismissBarButtonItem: UIBarButtonItem?
    private weak var resetBarButtonItem: UIBarButtonItem?
    private weak var saveStateBarButtonItem: UIBarButtonItem?
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
            let audioEnabled: Bool = UserDefaults.standard.bool(forKey: Settings.audioEnabledKey)
            let audioFiltersEnabled: Bool = UserDefaults.standard.bool(forKey: Settings.audioFiltersEnabledKey)
            let autoLoadSave: Bool = UserDefaults.standard.bool(forKey: Settings.loadLastSaveKey)
            let mostRecentState: ConsoleState? = autoLoadSave ? CoreDataController.mostRecentConsoleState(forMD5: safeCartridge.md5) : nil
            self.consoleQueue.async { [weak self] in
                self?.console = Console(withCartridge: safeCartridge, sampleRate: sampleRate, audioFiltersEnabled: audioFiltersEnabled, state: mostRecentState)
                self?.console?.set(audioEngineDelegate: audioEnabled ? self?.audioEngine : nil)
                if mostRecentState == nil
                {
                    self?.console?.reset()
                }
            }
        }
    }
    private let consoleQueue: DispatchQueue = DispatchQueue(label: "ConsoleQueue", qos: .userInteractive)
    private var hasSuspended: Bool = false
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
    private let audioEngine: AudioEngine = AudioEngine()
    
    // MARK: - Appearance
#if !os(tvOS)
    override var prefersHomeIndicatorAutoHidden: Bool { return true }
#endif
    
    // MARK: - UIResponder
    override var canBecomeFirstResponder: Bool
    {
        return true
    }
    
    // MARK: - UIViewController Life Cycle
    override func viewDidLoad()
    {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(appResignedActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        self.controllerUserInteractionEnabled = false
        self.consoleFrameQueueSize = NesRomViewController.defaultFrameQueueSize
        self.setupButtons()
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
#if os(tvOS)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
#endif
        NotificationCenter.default.addObserver(self, selector: #selector(handleControllerConnect(_:)), name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleControllerDisconnect(_:)), name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
        UIApplication.shared.isIdleTimerDisabled = true
        self.createDisplayLink()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        self.destroyDisplayLink()
#if os(tvOS)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
#endif
        self.resignFirstResponder()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    // MARK: EmulatorProtocol
    func pauseEmulation()
    {
        self.consoleFrameQueueSize = 0
        self.destroyDisplayLink()
    }
    
    func resumeEmulation()
    {
        self.consoleFrameQueueSize = NesRomViewController.defaultFrameQueueSize
        self.createDisplayLink()
    }
    
    // MARK: - ConsoleSaveStateSelectionDelegate
    func consoleStateSelected(consoleState aConsoleState: ConsoleState)
    {
        self.consoleQueue.async { [weak self] in
            self?.console?.load(state: aConsoleState)
            self?.console?.set(audioEngineDelegate: self?.audioEngine)
            DispatchQueue.main.async {
                self?.becomeFirstResponder()
            }
        }
    }
    
    func saveCurrentStateSelected()
    {
        self.consoleQueue.async { [weak self] in
            guard let safeState = self?.console?.consoleState(isAutoSave: false) else { return }
            DispatchQueue.main.async {
                do
                {
                    try CoreDataController.save(consoleState: safeState)
                }
                catch
                {
                    let alertVC = UIAlertController.init(title: NSLocalizedString("title-error", comment: "Error"), message: NSLocalizedString("error-failed-to-add-save-state", comment: "Failed to add save state"), preferredStyle: .alert)
                    alertVC.addAction(UIAlertAction.init(title: NSLocalizedString("button-ok", comment: "OK"), style: .cancel, handler: nil))
                    self?.present(alertVC, animated: true, completion: nil)
                }
                self?.becomeFirstResponder()
            }
        }
    }
    
    func consoleStateSelectionDismissed()
    {
        self.resumeEmulation()
    }
    
    // MARK: - Gesture Recognizers
    @IBAction func handleTap(_ gesture: UITapGestureRecognizer)
    {
        guard let isHidden = self.navigationController?.navigationBar.isHidden else { return }
        self.navigationController?.setNavigationBarHidden(!isHidden, animated: true)
    }
    
    // MARK: - Button Actions
    @objc private func dismissButtonPressed(_ sender: AnyObject?)
    {
        func dismissNesRomVC()
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
        
        let autoSave: Bool = UserDefaults.standard.bool(forKey: Settings.autoSaveKey)
        if autoSave
        {
            self.consoleQueue.async { [weak self] in
                let consoleState = self?.console?.consoleState(isAutoSave: true)
                DispatchQueue.main.async {
                    if let safeConsoleState = consoleState
                    {
                        do
                        {
                            try CoreDataController.save(consoleState: safeConsoleState)
                        }
                        catch
                        {
                            
                        }
                    }
                    dismissNesRomVC()
                }
            }
        }
        else
        {
            dismissNesRomVC()
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
    
    @objc private func saveStateButtonPressed(_ sender: AnyObject?)
    {
        guard let md5 = self.cartridge?.md5 else { return }
        self.pauseEmulation()
        self.performSegue(withIdentifier: "showSaveStates", sender: md5)
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
        for (index, controller) in [self.controller1, self.controller2].enumerated()
        {
            guard let extendedPad = controller?.capture().extendedGamepad else { continue }
            let isUp: Bool = extendedPad.dpad.up.isPressed || extendedPad.leftThumbstick.yAxis.value > NesRomViewController.analogDeadZoneUpDown
            let isDown: Bool = extendedPad.dpad.down.isPressed || extendedPad.leftThumbstick.yAxis.value < (-1.0 * NesRomViewController.analogDeadZoneUpDown)
            let isLeft: Bool = extendedPad.dpad.left.isPressed || extendedPad.leftThumbstick.xAxis.value < (-1.0 * NesRomViewController.analogDeadZoneLeftRight)
            let isRight: Bool = extendedPad.dpad.right.isPressed || extendedPad.leftThumbstick.xAxis.value > NesRomViewController.analogDeadZoneLeftRight
            self.consoleQueue.async { [weak self] in
                self?.console?.set(buttonUpPressed: isUp, buttonDownPressed: isDown, buttonLeftPressed: isLeft, buttonRightPressed: isRight, buttonSelectPressed: extendedPad.buttonOptions?.isPressed ?? extendedPad.buttonY.isPressed, buttonStartPressed: extendedPad.buttonMenu.isPressed, buttonBPressed: extendedPad.buttonX.isPressed, buttonAPressed: extendedPad.buttonA.isPressed, forControllerAtIndex: index)
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
            self?.console?.stepTick()
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
    
    @objc private func appResignedActive()
    {
        self.consoleQueue.suspend()
        self.hasSuspended = true
    }
    
    @objc private func appBecameActive()
    {
        if self.hasSuspended
        {
            self.consoleQueue.resume()
            self.hasSuspended = false
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
#if os(tvOS)

#else
        if let safeSaveStateVC = segue.destination as? ConsoleStateNavigationController,
           let md5 = sender as? String
        {
            self.resignFirstResponder()
            safeSaveStateVC.md5 = md5
            safeSaveStateVC.consoleSaveStateSelectionDelegate = self
        }
#endif
    }
    
    // MARK: - Private Functions
    
    private func createDisplayLink()
    {
        self.destroyDisplayLink()
        self.displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        self.displayLink?.preferredFramesPerSecond = 60
        self.displayLink?.add(to: RunLoop.current, forMode: RunLoop.Mode.default)
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
        let currentControllers: [GCController] = GCController.controllers().filter({ $0.extendedGamepad != nil })
        
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
                if c === self.controller2
                {
                    self.controller1 = c
                    self.controller2 = nil
                    break
                }
                else
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

        self.screenTapAreaBottomToButtons?.isActive = !hidden && self.traitCollection.horizontalSizeClass == .compact && self.traitCollection.verticalSizeClass == .regular
        self.screenTapAreaLeadingToButtons?.isActive = !hidden && self.traitCollection.horizontalSizeClass == .compact && self.traitCollection.verticalSizeClass == .compact
        self.screenTapAreaTrailingToButtons?.isActive = !hidden && self.traitCollection.horizontalSizeClass == .compact && self.traitCollection.verticalSizeClass == .compact
#endif
    }
    
    private func setupButtons()
    {
#if targetEnvironment(macCatalyst)
        let symbolPointSize: CGFloat = 17
#else
        let symbolPointSize: CGFloat = 21
#endif
        let symbolConfig = UIImage.SymbolConfiguration.init(pointSize: symbolPointSize, weight: .semibold)
        let resetButton: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "power", withConfiguration: symbolConfig), style: .plain, target: self, action: #selector(resetButtonPressed(_:)))
        let saveStateButton: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "bookmark", withConfiguration: symbolConfig), style: .plain, target: self, action: #selector(saveStateButtonPressed(_:)))
        let controller1Button: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gamecontroller", withConfiguration: symbolConfig), style: .plain, target: self, action: nil)
        let controller2Button: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gamecontroller", withConfiguration: symbolConfig), style: .plain, target: self, action: nil)
        let closeButton: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark", withConfiguration: symbolConfig), style: .plain, target: self, action: #selector(dismissButtonPressed(_:)))
        controller1Button.isEnabled = false
        controller2Button.isEnabled = false
        
        self.resetBarButtonItem = resetButton
        self.saveStateBarButtonItem = saveStateButton
        self.controller1BarButtonItem = controller1Button
        self.controller2BarButtonItem = controller2Button
        self.dismissBarButtonItem = closeButton
           
        self.navigationItem.setLeftBarButtonItems([resetButton, saveStateButton, controller1Button, controller2Button], animated: false)
        
#if targetEnvironment(macCatalyst)
#else
        self.navigationItem.setRightBarButtonItems([closeButton], animated: false)
#endif
    }
}
