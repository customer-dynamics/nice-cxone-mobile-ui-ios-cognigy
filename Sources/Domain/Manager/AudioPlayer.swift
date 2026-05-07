//
// Copyright (c) 2021-2026. NICE Ltd. All rights reserved.
//
// Licensed under the NICE License;
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://github.com/nice-devone/nice-cxone-mobile-ui-ios/blob/main/LICENSE
//
// TO THE EXTENT PERMITTED BY APPLICABLE LAW, THE CXONE MOBILE SDK IS PROVIDED ON
// AN "AS IS" BASIS. NICE HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS
// OR IMPLIED, INCLUDING (WITHOUT LIMITATION) WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND TITLE.
//

import AVFoundation
import SwiftUI

class AudioPlayer: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    @Binding var alertType: ChatAlertType?
    
    @Published var isPlaying = false
    @Published var formattedDuration: String
    @Published var formattedProgress: String
    
    private let audioSession: AudioSessionProviding
    private let audioPlayback: AudioPlaybackProviding
    private let audioFileDownloader: AudioFileDownloading
    private let formattedZeroDuration: String
    private let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        
        return formatter
    }()
    private let chatLocalization: ChatLocalization
    
    private var timer: Timer?
    private var fileName: String

    private(set) var url: URL
    
    var progress: Double {
        audioPlayback.playProgress
    }
    
    // MARK: - Lifecycle
    
    init(
        url: URL,
        fileName: String,
        alertType: Binding<ChatAlertType?>,
        chatLocalization: ChatLocalization,
        audioSession: AudioSessionProviding = AVAudioSession.sharedInstance(),
        audioPlayback: AudioPlaybackProviding = DefaultAudioPlaybackProvider(),
        audioFileDownloader: AudioFileDownloading = DefaultAudioFileDownloader()
    ) {
        self.url = url
        self.fileName = fileName
        self._alertType = alertType
        self.chatLocalization = chatLocalization
        self.audioSession = audioSession
        self.audioPlayback = audioPlayback
        self.audioFileDownloader = audioFileDownloader

        self.formattedZeroDuration = formatter.string(from: 0) ?? ""
        self.formattedDuration = formattedZeroDuration
        self.formattedProgress = formattedZeroDuration
    }
    
    deinit {
        reset()
    }
    
    // MARK: - Methods

    @MainActor
    func prepare() async {
        LogManager.trace("Preparing audio player")

        do {
            let fileUrl = try await audioFileDownloader.downloadAudioFile(from: url, fileName: fileName)
            audioPlayback.replaceCurrentItem(with: fileUrl)
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true, options: [])

            formattedProgress = safeFormatTimeInterval(0)
            let total = TimeInterval(audioPlayback.totalDuration)
            formattedDuration = safeFormatTimeInterval(total)
        } catch {
            error.logError()

            reset()
            alertType = .genericError(localization: chatLocalization)
        }
    }

    func play() {
        LogManager.trace("Playing audio")
        
        isPlaying = true

        if audioPlayback.playProgress == 1 {
            audioPlayback.seekToZero()
        }
        
        if timer == nil || timer?.isValid == false {
            timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
        }
        
        audioPlayback.play()
    }
    
    func pause() {
        LogManager.trace("Pausing audio")
        
        timer?.invalidate()
        audioPlayback.pause()
        isPlaying = false
    }
    
    func seek(_ value: Int) {
        LogManager.trace("Adjusting audio footage of \(value)")
        
        guard let duration = audioPlayback.currentItemDurationSeconds() else {
            LogManager.error("Unable to get duration to be able to seek to a specific time")
            return
        }

        let targetTime = audioPlayback.currentTimeSeconds() + Double(value)
        let clampedTargetTime = max(0.0, min(targetTime, duration))
        audioPlayback.seek(to: clampedTargetTime, duration: duration)
    }
}

// MARK: - Private methods

private extension AudioPlayer {
    
    /// Formats a time interval into a positional mm:ss string safely.
    ///
    /// Guards against non-finite (NaN/±infinity) and negative values that can
    /// cause `DateComponentsFormatter` to assert or crash. Non-finite or
    /// negative inputs are treated as 0.
    ///
    /// - Parameter interval: The raw `TimeInterval` to format.
    ///
    /// - Returns: A formatted string or `formattedZeroDuration` when input is invalid.
    func safeFormatTimeInterval(_ interval: TimeInterval) -> String {
        let clamped: TimeInterval = interval.isFinite && interval >= 0 ? interval : 0
        
        return formatter.string(from: clamped) ?? formattedZeroDuration
    }
    
    func reset() {
        LogManager.trace("Resetting AudioPlayer")
        
        isPlaying = false
        formattedProgress = formattedZeroDuration
        audioPlayback.pause()
        timer?.invalidate()
        try? audioSession.setActive(false, options: [])
    }
    
    @objc
    func timerAction() {
        formattedProgress = safeFormatTimeInterval(TimeInterval(audioPlayback.currentDuration))

        if audioPlayback.playProgress >= 1 {
            isPlaying = false
            timer?.invalidate()
        }
    }
}
