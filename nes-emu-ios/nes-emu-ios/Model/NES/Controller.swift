//
//  Controller.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/5/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

class Controller
{
    init(index aIndex: UInt8)
    {
        self.index = aIndex
    }
    
    let index: UInt8
    
    var upPressed: Bool = false
    var downPressed: Bool = false
    var leftPressed: Bool = false
    var rightPressed: Bool = false
    var bPressed: Bool = false
    var aPressed: Bool = false
    var selectPressed: Bool = false
    var startPressed: Bool = false
    
    var status: UInt8
    {
        return UInt8.init(fromBigEndianBitArray: [aPressed, bPressed, selectPressed, startPressed, upPressed, downPressed, leftPressed, rightPressed])
    }
}
