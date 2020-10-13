//
//  ConsoleState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/10/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

struct ConsoleState
{
    let isAutoSave: Bool
    let date: Date
    let md5: String
    let cpuState: CPUState
    let apuState: APUState
    let ppuState: PPUState
    let mapperState: MapperState
}
