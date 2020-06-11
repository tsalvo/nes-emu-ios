//
//  Controller.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/5/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

protocol ControllerProtocol: class
{
    func read() -> UInt8
    func write(value aValue: UInt8)
    func set(buttons aButtons: [Bool])
    func set(buttonAtIndex aIndex: Int, enabled aEnabled: Bool)
}

enum ControllerButton: Int
{
    case buttonA = 0,
    buttonB = 1,
    buttonSelect = 2,
    buttonStart = 3,
    buttonUp = 4,
    buttonDown = 5,
    buttonLeft = 6,
    buttonRight = 7
}

class Controller: ControllerProtocol
{
    var index: UInt8 = 0
    var buttons: [Bool] = [Bool].init(repeating: false, count: 8)
    var strobe: UInt8 = 0
    
    func read() -> UInt8
    {
        var value: UInt8 = 0
        
        if self.index < 8 && self.buttons[Int(self.index)]
        {
            value = 1
        }
        
        self.index += 1
        
        if self.strobe & 1 == 1
        {
            self.index = 0
        }
        return value
    }
    
    func write(value aValue: UInt8)
    {
        self.strobe = aValue
        if self.strobe & 1 == 1
        {
            self.index = 0
        }
    }
    
    func set(buttons aButtons: [Bool])
    {
        self.buttons = aButtons
    }
    
    func set(buttonAtIndex aIndex: Int, enabled aEnabled: Bool)
    {
        guard aIndex < 8 else { return }
        self.buttons[aIndex] = aEnabled
    }
}
