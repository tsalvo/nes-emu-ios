//
//  Filter.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/12/20.
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
