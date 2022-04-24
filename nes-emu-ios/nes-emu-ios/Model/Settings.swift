//
//  Settings.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/20/20.
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

protocol SettingsEnum
{
    var friendlyName: String { get }
    var storedValue: Any { get }
}

final class Settings
{
    // MARK: - UserDefaults Keys
    static let autoSaveKey: String = "autoSaveKey"
    static let loadLastSaveKey: String = "loadLastSaveKey"
    static let sampleRateKey: String = "sampleRateKey"
    static let audioEnabledKey: String = "audioEnabledKey"
    static let audioFiltersEnabledKey: String = "audioFiltersEnabledKey"
    static let audioSessionNotifyOthersOnDeactivationKey: String = "audioSessionNotifyOthersOnDeactivationKey"
    static let saveDataExistsKey: String = "saveDataExistsKey"
    static let nearestNeighborRenderingKey: String = "nearestNeighborRenderingKey"
    static let checkForRedundantFramesKey: String = "checkForRedundantFramesKey"
    static let integerScalingKey: String = "integerScalingKey"
    static let scanlinesKey: String = "scanlinesKey"
    
    // MARK: - Default Values
    static let defaultSampleRate: SampleRate = SampleRate._22050Hz
    static let defaultAudioSessionNotifyOthersOnDeactivation = true
    static let defaultAudioEnabled: Bool = true
    static let defaultAudioFiltersEnabled: Bool = true
    static let defaultAutoSaveKey: Bool = true
    static let defaultLoadLastSaveKey: Bool = true
    static let defaultSaveDataExistsKey: Bool = false
    static let defaultNearestNeighborRenderingKey: Bool = true
    static let defaultCheckForRedundantFramesKey: Bool = false
    static let defaultIntegerScalingKey: Bool = false
    static let defaultScanlinesKey: Scanlines = Scanlines.off

    final class func registerDefaultsIfNeeded()
    {
        UserDefaults.standard.register(defaults: [
            Settings.loadLastSaveKey: Settings.defaultLoadLastSaveKey,
            Settings.autoSaveKey: Settings.defaultAutoSaveKey,
            Settings.sampleRateKey: Settings.defaultSampleRate.rawValue,
            Settings.audioEnabledKey: Settings.defaultAudioEnabled,
            Settings.audioFiltersEnabledKey: Settings.defaultAudioFiltersEnabled,
            Settings.audioSessionNotifyOthersOnDeactivationKey: Settings.defaultAudioSessionNotifyOthersOnDeactivation,
            Settings.saveDataExistsKey: Settings.defaultSaveDataExistsKey,
            Settings.nearestNeighborRenderingKey: Settings.defaultNearestNeighborRenderingKey,
            Settings.checkForRedundantFramesKey: Settings.defaultCheckForRedundantFramesKey,
            Settings.integerScalingKey: Settings.defaultIntegerScalingKey,
            Settings.scanlinesKey: Int(Settings.defaultScanlinesKey.rawValue)
        ])
    }
    
    enum CellType
    {
        case Toggle, About, Info, Segmented, Confirmation
    }
    
    struct Cell
    {
        var key: String?
        var title: String?
        var description: String?
        var metadata: Any?
        var type: Settings.CellType = .Toggle
    }
    
    struct HelpEntry
    {
        var header: String
        var description: String
        var iconNames: [String]?
    }
    
    struct Section
    {
        var sectionName: String?
        var cells: [Settings.Cell]
    }
}
