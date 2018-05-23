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
    private var isPlaying = false
    @IBOutlet weak var playButton: UIButton!

    var player: AVQueuePlayer!
    var playerLooper: AVPlayerLooper!
    
    func activateAudioSession() throws {
        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        try AVAudioSession.sharedInstance().setActive(true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        var items = [AVPlayerItem]()
        ["go_up", "out_of_body", "ringo2_unreleased04"].forEach { trackName in
            let url = Bundle.main.url(forResource: trackName, withExtension: "mp3")!
            let item = AVPlayerItem(url: url)
            items.append(item)
        }
        player = AVQueuePlayer(items: items)
        playerLooper = AVPlayerLooper(player: player, templateItem: items[0])
        updateViews()
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
            self.navigateToNextSentence(loop: true)
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { _ in
            self.navigateToPreviousSentence(loop: true)
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

    func navigateToNextSentence(loop: Bool = false) {
        player.advanceToNextItem()
    }

    func navigateToPreviousSentence(loop: Bool = false) {

    }

    // MARK: -

    @IBAction func playButtonTapped(_ sender: Any) {
        togglePlaying()
    }

    @IBAction func previousButtonTapped(_ sender: Any) {
        navigateToPreviousSentence(loop: true)
    }

    @IBAction func nextButtonTapped(_ sender: Any) {
        navigateToNextSentence(loop: true)
    }


}

