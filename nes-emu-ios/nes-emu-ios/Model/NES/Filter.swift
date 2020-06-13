//
//  Filter.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/12/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

protocol Filter
{
    mutating func step(x aX: Float32) -> Float32
}

/// First order filters are defined by the following parameters: y[n] = B0*x[n] + B1*x[n-1] - A1*y[n-1]
struct FirstOrderFilter: Filter
{
    let B0: Float32
    let B1: Float32
    let A1: Float32
    var prevX: Float32
    var prevY: Float32
    
    mutating func step(x aX: Float32) -> Float32
    {
        let y = (self.B0 * aX) + (self.B1 * self.prevX) - (self.A1 * self.prevY)
        self.prevY = y
        self.prevX = aX
        return y
    }
}

struct FilterChain: Filter
{
    var filters: [Filter]
    
    mutating func step(x aX: Float32) -> Float32
    {
        var x = aX
        for i in 0 ..< self.filters.count
        {
            x = self.filters[i].step(x: x)
        }
        return x
    }
}

