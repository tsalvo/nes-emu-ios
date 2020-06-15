//
//  Console.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/5/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

protocol ConsoleProtocol: class
{
    var cpu: CPU { get }
}

class Console: ConsoleProtocol
{
    let apu: APU
    let ppu: PPU
    let cpu: CPU
    let cartridge: Cartridge
    let controllers: [Controller]
    let queue: DispatchQueue
    
    init(withCartridge aCartridge: Cartridge, sampleRate aSampleRate: SampleRate)
    {
        self.queue = DispatchQueue(label: "ConsoleQueue", qos: .userInteractive)
        let apu = APU(withSampleRate: aSampleRate)
        let controllers: [Controller] = [Controller(), Controller()]
        let mapper = aCartridge.mapper
        let ppu = PPU(mapper: mapper)
        let cpu = CPU(ppu: ppu, apu: apu, mapper: mapper, controller1: controllers[0], controller2: controllers[1])
        self.cpu = cpu
        self.apu = apu
        self.ppu = ppu
        self.cartridge = aCartridge
        self.controllers = controllers
        self.cpu.console = self
        self.apu.console = self
        self.ppu.console = self
        self.apu.cpu = cpu
    }
    
    func set(audioEngineDelegate aAudioEngineDelegate: AudioEngineProtocol?)
    {
        self.queue.async { [weak self] in
            self?.apu.audioEngineDelegate = aAudioEngineDelegate
        }
    }
    
    func set(button aButton: ControllerButton, enabled aEnabled: Bool, forControllerAtIndex aIndex: Int)
    {
        self.queue.async { [weak self] in
            guard aIndex < self?.controllers.count ?? Int.max else { return }
            self?.controllers[aIndex].set(buttonAtIndex: aButton.rawValue, enabled: aEnabled)
        }
    }
    
    /// set all buttons at once for a given controller
    func set(buttonUpPressed aButtonUpPressed: Bool, buttonDownPressed aButtonDownPressed: Bool, buttonLeftPressed aButtonLeftPressed: Bool, buttonRightPressed aButtonRightPressed: Bool, buttonSelectPressed aButtonSelectPressed: Bool, buttonStartPressed aButtonStartPressed: Bool, buttonBPressed aButtonBPressed: Bool, buttonAPressed aButtonAPressed: Bool, forControllerAtIndex aIndex: Int)
    {
        self.queue.async { [weak self] in
            guard aIndex < self?.controllers.count ?? Int.max else { return }
            self?.controllers[aIndex].set(buttons: [aButtonAPressed, aButtonBPressed, aButtonSelectPressed, aButtonStartPressed, aButtonUpPressed, aButtonDownPressed, aButtonLeftPressed, aButtonRightPressed])
        }
    }
    
    func reset(completionHandler aCompletionHandler: (() -> Void)?)
    {
        self.queue.async { [weak self] in
            
            self?.cpu.reset()
            self?.ppu.reset()
            
            DispatchQueue.main.async {
                aCompletionHandler?()
            }
        }
    }
    
    func stepSeconds(seconds aSeconds: Float64, completionHandler aCompletionHandler: (() -> Void)?)
    {
        self.queue.async { [weak self] in
            
            var cycles = Int(Float64(CPU.frequency) * aSeconds)
            while cycles > 0
            {
                cycles -= self?.step() ?? cycles
            }
            
            DispatchQueue.main.async {
                aCompletionHandler?()
            }
        }
    }
    
    private func step() -> Int
    {
        let cpuCycles = self.cpu.step()
        let ppuCycles = cpuCycles * 3
        
        for _ in 0 ..< ppuCycles
        {
            self.ppu.step(cpu: self.cpu)
        }
        
        for _ in 0 ..< cpuCycles
        {
            self.apu.step()
        }
        
        return cpuCycles
    }
    
    private func stepFrame() -> Int
    {
        var cpuCycles = 0
        let frame = self.ppu.frame
        while frame == self.ppu.frame
        {
            cpuCycles += self.step()
        }
        return cpuCycles
    }
}
