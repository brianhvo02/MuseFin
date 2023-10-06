//
//  AudioManager.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/4/23.
//

import AVFoundation
import MediaPlayer
import Nuke

class AudioManager: ObservableObject {
    @Published var isPlaying = false
    var audioPlayer: AVPlayer?
    var curTrack: Int = 0
    var listId: String = ""
    var trackList: [Track] = []
    var items: [AVPlayerItem] = []
    
    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [unowned self] event in
            if !isPlaying {
                play()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if isPlaying {
                pause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget() { [unowned self] event in
            guard
                let player = audioPlayer,
                let event = event as? MPChangePlaybackPositionCommandEvent
            else {
                return .commandFailed
            }
            player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: CMTimeScale(1000)))
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget() { [unowned self] event in
            if let track = nextTrack(), track {
                return .success
            } else {
                return .commandFailed
            }
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget() { [unowned self] event in
            if let track = prevTrack(), track {
                return .success
            } else {
                return .commandFailed
            }
        }
    }
    
    func prevTrack() -> Bool? {
        if curTrack > 0 {
            curTrack -= 1
            loadMusic()
            return true
        }
        
        return false
    }
    
    func nextTrack() -> Bool? {
        if curTrack < trackList.count - 1 {
            curTrack += 1
            loadMusic()
            return true
        }
        
        return false
    }
    
    func loadTracks(listId: String, trackIdx: Int = 0, trackList: [Track]) {
        self.listId = listId
        self.curTrack = trackIdx
        self.trackList = trackList
        self.items = trackList.compactMap { track in JellyfinAPI.shared.getAudioAsset(trackId: track.id) }
        loadMusic()
    }
    
    func loadMusic() {
        MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = curTrack > 0
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = curTrack < trackList.count - 1
        
        let track = trackList[curTrack]
        print("Now Playing:", track.name)
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: track.name,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyArtist: track.artists.joined(separator: ", "),
            MPMediaItemPropertyPlaybackDuration: String(track.runTimeTicks / 10000000)
        ] 
        var artwork = UIImage(named: "AppIconLight")
        
        if let image = artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { size in image }
        }
        
        if let artworkUrl = JellyfinAPI.shared.getAlbumImageUrl(albumId: track.albumId) {
            ImagePipeline.shared.loadImage(
                with: artworkUrl
            ) { result in
                switch result {
                case let .success(res):
                    artwork = res.image
                    break
                default: break
                }
                
                if let image = artwork {
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { size in image }
                }
                
                self.playMusic(nowPlayingInfo: nowPlayingInfo)
            }
        } else {
            self.playMusic(nowPlayingInfo: nowPlayingInfo)
        }
    }
    
    func playMusic(nowPlayingInfo: [String: Any]) {
        let nowPlayingCenter = MPNowPlayingInfoCenter.default()
        nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
        if let player = audioPlayer {
            player.seek(to: CMTime.zero)
            player.replaceCurrentItem(with: items[curTrack])
        } else {
            audioPlayer = AVPlayer(playerItem: items[curTrack])
        }
        play()
    }
    
    func play() {
        guard let player = audioPlayer else {
            return
        }
        isPlaying = true
        player.play()
        
        let nowPlayingCenter = MPNowPlayingInfoCenter.default()
        
        if var nowPlayingInfo = nowPlayingCenter.nowPlayingInfo {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
            nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
        }
    }
    
    func pause() {
        guard let player = audioPlayer else {
            return
        }
        isPlaying = false
        player.pause()
        
        let nowPlayingCenter = MPNowPlayingInfoCenter.default()
        
        if var nowPlayingInfo = nowPlayingCenter.nowPlayingInfo {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
            nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
        }
    }
}
