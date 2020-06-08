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
    
}

class Console: ConsoleProtocol
{
    init(withCartridge aCartridge: Cartridge)
    {
        let apu = APU()
        let ppu = PPU()
        
        self.cpu = CPU(ppu: ppu, apu: apu)
        self.apu = apu
        self.ppu = ppu
        self.cartridge = aCartridge
        self.mapper = aCartridge.mapperIdentifier.mapper(forCartridge: aCartridge)
        self.cpu.console = self
        self.apu.console = self
        self.ppu.console = self
        
    }
    
    let mapper: MapperProtocol?
    let apu: APU
    let ppu: PPU
    let cpu: CPU
    let cartridge: Cartridge
    let controllers: [Controller] = [Controller(index: 0), Controller(index: 1)]
}
