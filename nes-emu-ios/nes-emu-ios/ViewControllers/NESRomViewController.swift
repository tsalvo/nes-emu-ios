//
//  NESRomViewController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/8/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit

class NESRomViewController: UIViewController
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
    
    var document: NesRomDocument?
    var console: Console?
    private var displayLink: CADisplayLink?
    private var audioEngine: AudioEngine = AudioEngine()
    
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
        self.createDisplayLink()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        self.displayLink?.invalidate()
    }
    
    @IBAction private func dismiss(_ sender: AnyObject?)
    {
        if !self.isBeingDismissed
        {
            self.displayLink?.invalidate()
            self.dismiss(animated: true, completion: nil)
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
        self.console?.stepSeconds(seconds: 1.0 / 60.0, completionHandler: { [weak self] in
            self?.screen.buffer = self?.console?.ppu.frontBuffer ?? []
        })
    }
    
    private func createDisplayLink()
    {
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        self.displayLink?.preferredFramesPerSecond = 60
        self.displayLink?.add(to: RunLoop.current, forMode: RunLoop.Mode.default)
        self.displayLink?.add(to: RunLoop.current, forMode: RunLoop.Mode.tracking)
    }
}
