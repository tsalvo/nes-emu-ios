//
//  AudioEngine.swift
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
import AVFoundation
import os

enum AudioEngineState { case stopped, started, paused, playing }

protocol AudioEngineProtocol: class
{
    func schedule(buffer aBuffer: [Float32], withSampleRate aSampleRate: SampleRate)
}

class AudioEngine: AudioEngineProtocol
{
    private let queue: DispatchQueue = DispatchQueue(label: "AudioEngineQueue", qos: .default)
    private let engine: AVAudioEngine = AVAudioEngine.init()
    private let playerNode: AVAudioPlayerNode = AVAudioPlayerNode.init()
    private var engineState: AudioEngineState = .stopped
    private var currentAudioFormat: AVAudioFormat?
    private var lastSampleRate: SampleRate?
    
    func schedule(buffer aBuffer: [Float32], withSampleRate aSampleRate: SampleRate)
    {
        self.queue.async { [weak self] in
            
            if let safeLastSampleRate = self?.lastSampleRate,
                safeLastSampleRate != aSampleRate
            {
                self?.engine.stop()
            }
            
            switch self?.engineState ?? .stopped
            {
            case .stopped, .paused:
                do
                {
                    try self?.startEngine(withSampleRate: aSampleRate)
                }
                catch
                {
                    return
                }
                fallthrough
            case .playing, .started:
                guard let format: AVAudioFormat = AVAudioFormat.init(standardFormatWithSampleRate: aSampleRate.doubleValue, channels: 1),
                    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: aSampleRate.bufferCapacity)
                    else
                {
                    return
                }
                    
                buffer.frameLength = buffer.frameCapacity
                let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
                let _ = aBuffer.withUnsafeBytes { ptr in
                    memcpy(UnsafeMutableRawPointer(channels[0]), ptr.baseAddress, MemoryLayout<Float32>.size * aBuffer.count)
                    self?.playerNode.scheduleBuffer(buffer, completionHandler: nil)
                    self?.play()
                }
            }
        }
    }
    
    private func play()
    {
        switch self.engineState
        {
        case .started:
            
            self.setPlaybackCategory()
            self.playerNode.play(at: nil)
            self.engineState = .playing
            
        default:
            break
        }
    }
    
    private func stop()
    {
        switch self.engineState
        {
        case .started, .playing, .paused:
            
            self.playerNode.stop()
            self.engine.stop()
            self.engine.reset()
            for p in self.engine.attachedNodes.compactMap({ $0 as? AVAudioPlayerNode }) { self.engine.detach(p) }
            self.engineState = .stopped
            self.setAudioSessionInactive()
            
        default:
            break
        }
    }
        
    private func audioFormat(forSampleRate aSampleRate: SampleRate) throws -> AVAudioFormat
    {
        if let safeAudioFormat = AVAudioFormat.init(standardFormatWithSampleRate: aSampleRate.doubleValue, channels: 1),
            let _ = AVAudioPCMBuffer(pcmFormat: safeAudioFormat, frameCapacity: aSampleRate.bufferCapacity)
        {
            self.currentAudioFormat = safeAudioFormat
            return safeAudioFormat
        }
        else if let fallbackAudioFormat = AVAudioFormat.init(standardFormatWithSampleRate: 44100, channels: 1),
            let _ = AVAudioPCMBuffer(pcmFormat: fallbackAudioFormat, frameCapacity: aSampleRate.bufferCapacity)
        {
            self.currentAudioFormat = fallbackAudioFormat
            return fallbackAudioFormat
        }
        else
        {
            throw NSError(domain: "", code: 1000, userInfo: nil)
        }
    }
    
    private func startEngine(withSampleRate aSampleRate: SampleRate) throws
    {
        let audioFormat: AVAudioFormat
        do
        {
            audioFormat = try self.audioFormat(forSampleRate: aSampleRate)
        }
        catch
        {
            throw error
        }
        
        do
        {
            try self.startEngine(withAudioFormat: audioFormat)
        }
        catch
        {
            throw error
        }
    }
    
    private func startEngine(withAudioFormat aAudioFormat: AVAudioFormat) throws
    {
        switch self.engineState
        {
        case .stopped:
            
            self.engine.mainMixerNode.volume = 1.0
            
            self.attachNodesToEngineIfNeeded(withAudioFormat: aAudioFormat)
    
            do
            {
                try self.engine.start()
            }
            catch
            {
                throw error
            }
            
            if self.engineState == .stopped
            {
                self.engineState = .started
            }
            
        case .paused:
            
            do
            {
                try self.engine.start()
            }
            catch
            {
                throw error
            }
            
        default: break
        }
    }
    
    private func attachNodesToEngineIfNeeded(withAudioFormat aAudioFormat: AVAudioFormat)
    {
        guard self.engine.attachedNodes.compactMap({ $0 as? AVAudioPlayerNode }).isEmpty else { return }
        self.engine.attach(self.playerNode)
        self.engine.connect(self.playerNode, to: self.engine.mainMixerNode, format: aAudioFormat)
    }
    
    private func setPlaybackCategory()
    {
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio, options: []) }
        catch { os_log(OSLogType.error, "Failed to set audio session playback category: %@", error.localizedDescription) }
       
        do { try AVAudioSession.sharedInstance().setActive(true, options: []) }
        catch { os_log(OSLogType.error, "Failed to set audio session active: %@", error.localizedDescription) }
    }
   
    private func setAudioSessionInactive()
    {
        let notifyOthers: Bool = UserDefaults.standard.bool(forKey: Settings.audioSessionNotifyOthersOnDeactivationKey)
       
        do { try AVAudioSession.sharedInstance().setActive(false, options: notifyOthers ? .notifyOthersOnDeactivation : []) }
        catch { os_log(OSLogType.error, "Failed to set audio session inactive: %@", error.localizedDescription) }
    }
}
