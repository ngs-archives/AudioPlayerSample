//
//  ViewController.swift
//  AudioPlayerSample
//
//  Created by Atsushi Nagase on 5/23/18.
//  Copyright © 2018 LittleApps Inc. All rights reserved.
//

import UIKit
import MediaPlayer

class ViewController: UIViewController {
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var debugLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!

    var isPlaying = false
    let tracks = ["one.mp3", "two.mp3", "three.mp3"]
    let silentAudioFileName = "silent.mp3"
    let silentDuration = CMTimeMakeWithSeconds(1, 1)
    var fullItems: [AVPlayerItem] = []
    var player: AVQueuePlayer!
    var timeObserverToken: Any?
    private var playerItemContext = 0
    private var playerContext = 0
    
    func activateAudioSession() throws {
        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        try AVAudioSession.sharedInstance().setActive(true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateViews()
        loadTracks()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        try! activateAudioSession()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        self.becomeFirstResponder()

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { _ in
            guard !self.isPlaying else {
                return .commandFailed
            }
            self.play()
            self.updateViews()
            return .success
        }
        commandCenter.pauseCommand.addTarget { _ in
            guard self.isPlaying else {
                return .commandFailed
            }
            self.stop()
            self.updateViews()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { _ in
            self.navigateToNextTrack(loop: true)
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { _ in
            self.navigateToPreviousTrack(loop: true)
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            self.togglePlaying()
            return .success
        }
    }

    // MARK: -

    func play() {
        if isPlaying { return }
        isPlaying = true
        player.play()
        updateViews()
    }

    func stop() {
        if !isPlaying { return }
        isPlaying = false
        player.pause()
        updateViews()
    }

    func togglePlaying() {
        if isPlaying {
            stop()
        } else {
            play()
        }
    }

    func updateViews() {
        playButton.setImage(isPlaying ? #imageLiteral(resourceName: "PauseButton") : #imageLiteral(resourceName: "PlayButton"), for: .normal)
    }

    func navigateToNextTrack(loop: Bool = false) {
        var index: Int
        if let currentIndex = currentIndex {
            index = currentIndex + (currentIndex % 2 == 0 ? 2 : 1)
        } else {
            index = 0
        }
        if index >= fullItems.count {
            if !loop {
                return
            }
            index = 0
        }
        loadTracks(from: index)
    }

    var currentIndex: Int? {
        guard
            let currentItem = player.currentItem,
            let index = fullItems.index(of: currentItem)
            else {
                return nil
        }
        return index
    }

    var previousItem: AVPlayerItem? {
        guard let currentIndex = currentIndex, currentIndex > 0 else {
            return nil
        }
        return fullItems[currentIndex - 1]
    }

    var playerItemDuration: CMTime {
        guard let item = player?.currentItem, item.status == .readyToPlay else {
            return kCMTimeInvalid
        }
        if isPlayingSilent {
            if let previousItem = previousItem {
                return previousItem.duration + silentDuration
            }
            return kCMTimeInvalid
        }
        let itemDuration = item.duration
        return itemDuration + silentDuration
    }

    var silentAudioOffset: CMTime {
        return CMTimeMakeWithSeconds(20, 1) - silentDuration
    }

    var isPlayingSilent: Bool {
        guard let item = player?.currentItem, let asset = item.asset as? AVURLAsset else {
            return false
        }
        return asset.url.lastPathComponent == silentAudioFileName
    }

    func navigateToPreviousTrack(loop: Bool = false) {
        var index: Int
        if let currentIndex = currentIndex {
            index = currentIndex - (currentIndex % 2 == 0 ? 2 : 1)
        } else {
            index = -1
        }
        if index < 0 {
            if loop {
                index = fullItems.count - 2
            } else {
                return
            }
        }
        loadTracks(from: index)
    }

    func loadTracks(from trackIndex: Int = 0) {
        print(trackIndex)
        fullItems = []
        let silentURL = Bundle.main.url(forResource: silentAudioFileName, withExtension: nil)!
        tracks.forEach { trackName in
            let url = Bundle.main.url(forResource: trackName, withExtension: nil)!
            fullItems.append(AVPlayerItem(url: url))
            let silentItem = AVPlayerItem(url: silentURL)
            silentItem.seek(to: silentAudioOffset, completionHandler: nil)
            fullItems.append(silentItem)
        }
        fullItems.forEach { item in
            NotificationCenter.default.addObserver(
                self, selector: #selector(self.endPlaying),
                name: .AVPlayerItemDidPlayToEndTime, object: item)
            item.addObserver(self,
                             forKeyPath: #keyPath(AVPlayerItem.status),
                             options: [.old, .new],
                             context: &playerItemContext)
        }
        let items = fullItems.suffix(from: trackIndex)
        let isPlaying = player?.rate == 1
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
        player = AVQueuePlayer(items: Array(items))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: CMTimeMake(1, 60), queue: DispatchQueue.main) { [weak self] (time) in
            guard let `self` = self else { return }

            let duration = self.playerItemDuration
            let progress: Float
            if CMTIME_IS_VALID(duration) {
                if self.isPlayingSilent {
                    if let previousDuration = self.previousItem?.duration {
                        progress = Float(CMTimeGetSeconds(time + previousDuration - self.silentAudioOffset) / CMTimeGetSeconds(duration))
                    } else {
                        progress = 0
                    }
                } else {
                    progress = Float(CMTimeGetSeconds(time) / CMTimeGetSeconds(duration))
                }
            } else {
                progress = 0
            }
            self.progressView.progress = progress
        }
        player.addObserver(self,
                           forKeyPath: #keyPath(AVPlayer.timeControlStatus),
                           options: [.old, .new],
                           context: &playerItemContext)
        if isPlaying {
            player.play()
        }
    }

    @objc func endPlaying() {
        if player.items().count <= 1 {
            loadTracks(from: 0)
        }
    }

    func updateLabel() {
        guard !isPlayingSilent else { return }
        let filename = (player.currentItem?.asset as? AVURLAsset)?.url.lastPathComponent
        debugLabel.text = filename
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        switch context {
        case &playerItemContext:
            guard let playerItem = object as? AVPlayerItem,
                keyPath == #keyPath(AVPlayerItem.status) else { return }
            let status: AVPlayerItemStatus
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItemStatus(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            self.playerItem(playerItem, didChangeStatus: status)
            return
        case &playerContext:
            guard
                let player = object as? AVPlayer,
                let statusNumber = change?[.newKey] as? NSNumber,
                let status = AVPlayerTimeControlStatus(rawValue: statusNumber.intValue),
                keyPath == #keyPath(AVPlayer.timeControlStatus) else { return }
            self.player(player, didChangeTimeControlStatus: status)
            return
        default:
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
    }

    func playerItem(_ playerItem: AVPlayerItem, didChangeStatus status: AVPlayerItemStatus) {
        updateLabel()
    }

    func player(_ player: AVPlayer, didChangeTimeControlStatus status: AVPlayerTimeControlStatus) {
        updateLabel()
    }

    // MARK: -

    @IBAction func playButtonTapped(_ sender: Any) {
        togglePlaying()
    }

    @IBAction func previousButtonTapped(_ sender: Any) {
        navigateToPreviousTrack(loop: true)
    }

    @IBAction func nextButtonTapped(_ sender: Any) {
        navigateToNextTrack(loop: true)
    }


}

