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
    
    var document: NesRomDocument?
    var console: Console?
    var displayLink: CADisplayLink?
    
    let consoleQueue: DispatchQueue = DispatchQueue(label: "consoleQueue", qos: .userInteractive)
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        if let safeCartridge = self.document?.cartridge
        {
            self.console = Console(withCartridge: safeCartridge)
            self.console?.reset()
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.displayLink?.invalidate()
        self.displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        self.displayLink?.preferredFramesPerSecond = 60
        self.displayLink?.add(to: RunLoop.current, forMode: RunLoop.Mode.default)
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
    
    @objc private func updateFrame()
    {
        self.console?.stepSeconds(seconds: 1.0 / 60.0, queue: self.consoleQueue, completionQueue: DispatchQueue.main, completionHandler: { [weak self] in
            //NSLog("frame update")
            self?.screen.buffer = self?.console?.ppu.frontBuffer ?? []
        })
    }
}
