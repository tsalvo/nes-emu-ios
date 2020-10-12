//
//  Data+ValueConversion.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/10/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

extension Data
{
    /// https://stackoverflow.com/questions/38023838/round-trip-swift-number-types-to-from-data
    
    init<T>(from value: T)
    {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }
    
    init<T>(fromArray array: [T])
    {
        self = array.withUnsafeBytes { Data($0) }
    }
    
    func to<T>(type: T.Type) -> T? where T: ExpressibleByIntegerLiteral
    {
        var value: T = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
        return value
    }

    func toArray<T>(type: T.Type) -> [T] where T: ExpressibleByIntegerLiteral
    {
        var array = Array<T>(repeating: 0, count: self.count/MemoryLayout<T>.stride)
        _ = array.withUnsafeMutableBytes { copyBytes(to: $0) }
        return array
    }
}
