//
//  MirroringMode.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/14/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

enum MirroringMode: UInt8
{
    case horizontal = 0,
    vertical = 1,
    single0 = 2,
    single1 = 3,
    fourScreen = 4
}
