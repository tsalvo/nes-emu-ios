//
//  Bundle+Version.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 5/12/19.
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

extension Bundle
{
    struct Version: Comparable
    {
        static func < (lhs: Bundle.Version, rhs: Bundle.Version) -> Bool
        {
            if lhs.major == rhs.major {
                if lhs.minor == rhs.minor {
                    if lhs.revision == rhs.revision {
                        return lhs.build < rhs.build
                    } else {
                        return lhs.revision < rhs.revision
                    }
                } else {
                    return lhs.minor < rhs.minor
                }
            } else {
                return lhs.major < rhs.major
            }
        }
        
        var major: Int
        var minor: Int
        var revision: Int
        let build: Int
    }
    
    var friendlyAppNameVersionString: String
    {
        let versionString: String = self.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return self.appName + " " + versionString
    }
    
    var friendlyAppNameVersionBuildString: String
    {
        let versionString: String = self.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildString: String? = self.infoDictionary?["CFBundleVersion"] as? String
        let buildComponent: String = (buildString != nil) ? (" (build " + (buildString ?? "") + ")") : ""
        return self.appName + " " + versionString + buildComponent
    }
    
    var appName: String
    {
        return self.infoDictionary?["CFBundleDisplayName"] as? String ?? "nes-emu-ios"
    }
    
    var version: Bundle.Version
    {
        var major: Int = 1
        var minor: Int = 0
        var revision: Int = 0
        
        let versionString: String = self.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildString: String = self.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let build: Int = Int(buildString) ?? 1
        
        let components = versionString.components(separatedBy: ".")
        
        switch components.count
        {
        case 0: break
        case 1: major = Int(components[0]) ?? 1
        case 2:
            major = Int(components[0]) ?? 1
            minor = Int(components[1]) ?? 0
        default:
            major = Int(components[0]) ?? 1
            minor = Int(components[1]) ?? 0
            revision = Int(components[2]) ?? 0
        }
        
        return Bundle.Version(major: major, minor: minor, revision: revision, build: build)
    }
}
