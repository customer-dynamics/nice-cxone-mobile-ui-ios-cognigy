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
import Combine
import SwiftUI

class AudioRecorder: NSObject, ObservableObject {
    
    // MARK: - Objects
    
    enum VoiceMessageState {
        case idle
        case recording
        case recorded
        case playing
        case paused
    }

    struct AudioFileType {
        let `extension`: String
        let mimeType: String
    }
    
    // MARK: - Properties
    
    @Published var time: TimeInterval = 0
    @Published var length: TimeInterval = 0
    @Published var state: VoiceMessageState = .idle
    
    @Binding var alertType: ChatAlertType?
    
    private let localization: ChatLocalization
    private let audioSession: AudioSessionProviding
    private let audioRecording: AudioRecordingProviding
    private let audioPlayer: AudioPlayerProviding
    private var ticks = [AnyCancellable]()
    private var url: URL?
    
    var attachmentItem: AttachmentItem?
    
    var formattedCurrentTime: String {
        formatted(time)
    }
    var formattedLength: String {
        formatted(length)
    }
    
    static let currentAudioFile = AudioFileType(extension: "m4a", mimeType: "audio/x-m4a")

    // MARK: - Init
    
    init(
        alertType: Binding<ChatAlertType?>,
        localization: ChatLocalization,
        audioSession: AudioSessionProviding = AVAudioSession.sharedInstance(),
        audioRecording: AudioRecordingProviding = DefaultAudioRecordingProvider(),
        audioPlayer: AudioPlayerProviding = DefaultAudioPlayerProvider()
    ) {
        self._alertType = alertType
        self.localization = localization
        self.audioSession = audioSession
        self.audioRecording = audioRecording
        self.audioPlayer = audioPlayer
        super.init()

        setupDelegateCallbacks()
    }
    
    // MARK: - Methods
    
    func record() {
        LogManager.trace("Recording voice message")
        
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            guard self.isRecordPermissionGranted() else {
                LogManager.error(.failed("Record permission not granted"))
                return
            }
            
            do {
                try self.setupRecorder()
                
                guard state != .recording else {
                    LogManager.error(.failed("Unable to record - already recording"))
                    return
                }
                guard audioRecording.url != nil else {
                    LogManager.error(.failed("Unable to record - recorder URL not set"))
                    return
                }

                try self.audioSession.setCategory(.playAndRecord, options: .defaultToSpeaker)
                try self.audioSession.setActive(true, options: [])
                
                self.time = 0
                
                Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in self.updateTimer() }
                    .store(in: &ticks)
                
                audioRecording.record()
                
                self.state = .recording
            } catch {
                error.logError()
                
                self.attachmentItem = nil
                
                do {
                    try self.eraseAudioRecorder(deleteRecording: true)
                } catch {
                    error.logError()
                }
                
                self.state = .idle
                self.alertType = .genericError(localization: localization)
            }
        }
    }
    
    func stopRecording() {
        LogManager.trace("Recording has been stopped")
        
        ticks.cancel()
        
        do {
            try eraseAudioRecorder(deleteRecording: false)
            
            state = .recorded
        } catch {
            error.logError()
            
            attachmentItem = nil
            
            state = .idle
            alertType = .genericError(localization: localization)
        }
    }
    
    func play() {
        LogManager.trace("Playing recorded voice message")
        
        guard ![.playing, .recording].contains(state) else {
            LogManager.error(.failed("Recording or already playing."))
            return
        }
        guard let recorderUrl = audioRecording.url else {
            LogManager.error(.failed("Audio Recorder is not set"))
            return
        }

        if let url, recorderUrl == url, audioPlayer.currentTime != 0 {
            state = .playing
            audioPlayer.play()
        } else {
            do {
                try audioPlayer.loadAudio(from: recorderUrl)
                audioPlayer.prepareToPlay()

                url = audioRecording.url
                
                state = .playing
                audioPlayer.play()
                
                if audioPlayer.currentTime == 0 {
                    time = 0
                }
                
                Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in self?.updateTimer() }
                    .store(in: &ticks)
            } catch {
                error.logError()
                
                ticks.cancel()
                attachmentItem = nil
                
                do {
                    try eraseAudioRecorder(deleteRecording: true)
                } catch {
                    error.logError()
                }
                
                eraseAudioPlayer()
                
                state = .idle
                alertType = .genericError(localization: localization)
            }
        }
    }
    
    func pause() {
        LogManager.trace("Recorded voice message has been paused")
        
        ticks.cancel()
        audioPlayer.pause()
        
        state = .paused
    }
    
    func delete() {
        LogManager.trace("Removing recorded voice message")
        
        ticks.cancel()
        attachmentItem = nil
        
        do {
            try eraseAudioRecorder(deleteRecording: true)
        } catch {
            error.logError()
        }
        
        eraseAudioPlayer()
        
        state = .idle
    }
}

// MARK: - Private methods

private extension AudioRecorder {

    func setupDelegateCallbacks() {
        audioRecording.onFinishRecording = { [weak self] flag in
            self?.handleRecordingFinished(successfully: flag)
        }
        audioRecording.onEncodeError = { [weak self] error in
            self?.handleRecordingEncodeError(error)
        }
        audioPlayer.onFinishPlaying = { [weak self] flag in
            self?.handlePlayingFinished(successfully: flag)
        }
        audioPlayer.onDecodeError = { [weak self] error in
            self?.handlePlayingDecodeError(error)
        }
    }

    func handleRecordingFinished(successfully flag: Bool) {
        LogManager.trace("Voice message recording did finish \(flag ? "successfully" : "unsuccessfully")")

        ticks.cancel()

        // Successful flag is handled in the trigger place, e.g. "delete" or "stop" method
        if !flag {
            attachmentItem = nil

            do {
                try eraseAudioRecorder(deleteRecording: true)
            } catch {
                error.logError()
            }

            state = .idle
            alertType = .genericError(localization: localization)
        }
    }

    func handleRecordingEncodeError(_ error: Error?) {
        LogManager.trace("Error occured during encoding")

        error?.logError()

        ticks.cancel()
        attachmentItem = nil

        do {
            try eraseAudioRecorder(deleteRecording: true)
        } catch {
            error.logError()
        }

        state = .idle
        alertType = .genericError(localization: localization)
    }

    func handlePlayingFinished(successfully flag: Bool) {
        LogManager.trace("Playing recorded voice message did finish \(flag ? "successfully" : "unsuccessfully")")

        ticks.cancel()

        if flag {
            state = .recorded
        } else {
            attachmentItem = nil
            eraseAudioPlayer()

            state = .idle
            alertType = .genericError(localization: localization)
        }
    }

    func handlePlayingDecodeError(_ error: Error?) {
        LogManager.trace("Error occured during decoding")

        error?.logError()

        ticks.cancel()
        attachmentItem = nil
        eraseAudioPlayer()

        state = .idle
        alertType = .genericError(localization: localization)
    }

    func eraseAudioPlayer() {
        LogManager.trace("Erasing audio player")
        
        length = time
        time = 0
        audioPlayer.stop()
    }
    
    /// Cleans up and stops the current audio recording session.
    ///
    /// This method handles the cleanup of the audio recorder by stopping the recording,
    /// optionally deleting the recorded file, and deactivating the audio session.
    ///
    /// - Parameter deleteRecording: Whether to delete the recorded audio file from storage.
    ///   - Set to `true` when permanently removing a recording (e.g., when deleting or canceling).
    ///   - Set to `false` when transitioning states but keeping the recording (e.g., when stopping a recording to save it).
    /// - Throws: An error if deactivating the audio session fails.
    func eraseAudioRecorder(deleteRecording: Bool) throws {
        LogManager.trace("Erasing audio recorder")
        
        length = time
        time = 0
        audioRecording.stop()

        if deleteRecording {
            audioRecording.deleteRecording()
        }

        try audioSession.setActive(false, options: [])
    }
    
    func updateTimer() {
        time += 1
    }
    
    func isRecordPermissionGranted() -> Bool {
        guard audioSession.recordPermission != .granted else {
            return true
        }

        if audioSession.recordPermission == .denied {
            alertType = .microphonePermissionDenied(localization: localization) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else {
                    LogManager.error("Unable to get Settings URL")
                    return
                }
                
                Task { @MainActor in
                    UIApplication.shared.open(url)
                }
            }
            
            return false
        } else {
            audioSession.requestRecordPermission { granted in
                LogManager.trace("Record permission granted: \(granted)")
            }
            
            return false
        }
    }
    
    func setupRecorder() throws {
        LogManager.trace("Setting up recorder")
        
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            LogManager.error(.failed("Unable to get caches directory"))
            return
        }
        
        let recordingName = "voice_message_\(Date().formatted(format: "HH:mm:ss_dd-MM-YY")).\(Self.currentAudioFile.extension)"
        let bundle = cachesDirectory.appendingPathComponent(recordingName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        try audioRecording.setupRecorder(url: bundle, settings: settings)
        url = audioRecording.url
        attachmentItem = AttachmentItem(url: bundle, friendlyName: recordingName, mimeType: bundle.mimeType, fileName: recordingName)
    }
    
    func formatted(_ value: TimeInterval) -> String {
        let components = DateComponentsFormatter()
        components.allowedUnits = value >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        components.zeroFormattingBehavior = .pad
        
        return components.string(from: value) ?? ""
    }
}
