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
import Mockable

@Mockable
protocol AudioPlaybackProviding {

    // MARK: - Properties

    var playProgress: Double { get }
    var currentDuration: Double { get }
    var totalDuration: Double { get }

    // MARK: - Methods

    func replaceCurrentItem(with url: URL)
    func play()
    func pause()
    func seekToZero()
    func seek(to seconds: Double, duration: Double)
    func currentTimeSeconds() -> Double
    func currentItemDurationSeconds() -> Double?
}

class DefaultAudioPlaybackProvider: AudioPlaybackProviding {

    // MARK: - Properties

    private var avPlayer = AVPlayer()

    var playProgress: Double {
        avPlayer.playProgress
    }

    var currentDuration: Double {
        avPlayer.currentDuration
    }

    var totalDuration: Double {
        avPlayer.totalDuration
    }

    // MARK: - Methods

    func replaceCurrentItem(with url: URL) {
        avPlayer.replaceCurrentItem(with: AVPlayerItem(url: url))
    }

    func play() {
        avPlayer.play()
    }

    func pause() {
        avPlayer.pause()
    }

    func seekToZero() {
        avPlayer.seek(to: .zero)
    }

    func seek(to seconds: Double, duration: Double) {
        guard seconds.isFinite, duration.isFinite, duration > 0 else {
            return
        }

        let clampedSeconds = min(max(0, seconds), duration)
        let time = CMTimeMake(value: Int64(clampedSeconds * 1000 as Float64), timescale: 1000)

        avPlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func currentTimeSeconds() -> Double {
        let seconds = CMTimeGetSeconds(avPlayer.currentTime())

        return seconds.isFinite && seconds >= 0 ? seconds : 0
    }

    func currentItemDurationSeconds() -> Double? {
        guard let seconds = avPlayer.currentItem?.duration.seconds,
              seconds.isFinite,
              seconds > 0
        else {
            return nil
        }

        return seconds
    }
}
