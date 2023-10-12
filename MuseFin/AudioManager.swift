//
//  AudioManager.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/4/23.
//

import UIKit
import AVFoundation
import MediaPlayer

struct TrackMetadata {
    let id: String
    let name: String
    let albumName: String
    let artist: String
    let duration: Double
    let listName: String
    let artwork: UIImage?
    let blurHash: String?
}

enum RepeatMode {
    case off
    case list
    case track
}

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    var audioPlayer = AVQueuePlayer()
    @Published var listId: String = ""
    @Published var currentTrack: TrackMetadata?
    @Published var isPlaying = false
    @Published var elapsed = 0.0
    @Published var isEditing = false
    @Published var repeatMode: RepeatMode = .off
    
    var trackAssets: [AVPlayerItem] = []
    var trackMetadata: [TrackMetadata] = []
    var playerElapsedTimeObserver: Any?
    var playerStatusObserver: NSKeyValueObservation?
    var playerCurrentItemObserver: NSKeyValueObservation?
    var nowPlayingInfo: [String: Any] = [:]
    
    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [unowned self] _ in
            if !isPlaying {
                play()
                return .success
            }
            return .commandFailed
        }

        commandCenter.pauseCommand.addTarget { [unowned self] _ in
            if isPlaying {
                pause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.nextTrackCommand.addTarget { [unowned self] _ in
            next()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [unowned self] _ in
            prev()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                seek(event.positionTime)
                return .success
            }
            return .commandFailed
        }
        
        playerCurrentItemObserver = audioPlayer.observe(
            \.currentItem,
             options:  [.new, .old],
             changeHandler: self.onCurrentItemChange
        )
        playerElapsedTimeObserver = audioPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: DispatchQueue.main,
            using: onElapsedTimeChange
        )
    }
    
    func getAssetIndex(_ asset: AVPlayerItem) -> Int? {
        return trackAssets.firstIndex(of: asset)
    }
    
    func getCurrentIndex() -> Int? {
        guard let asset = audioPlayer.currentItem else {
            return nil
        }
        
        return getAssetIndex(asset)
    }
    
    func play() {
        audioPlayer.play()
        isPlaying = true
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioPlayer.currentTime().seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func pause() {
        audioPlayer.pause()
        isPlaying = false
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioPlayer.currentTime().seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func prev() {
        if audioPlayer.currentTime().seconds > 3 {
            seek(0)
            return
        }
        
        if
            let asset = audioPlayer.currentItem,
            let trackIdx = trackAssets.firstIndex(of: asset)
        {
            if repeatMode == .off && trackIdx == 0 {
                return
            }
            
            pause()
            
            if repeatMode == .track {
                repeatMode = .list
                repeatOne()
            }
            
            if trackIdx == 0 {
                if let lastAsset = trackAssets.last {
                    audioPlayer.removeAllItems()
                    audioPlayer.insert(lastAsset, after: nil)
                }
            } else {
                let prevAsset = trackAssets[trackIdx - 1]
                audioPlayer.replaceCurrentItem(with: prevAsset)
                audioPlayer.seek(to: CMTime.zero)
                audioPlayer.insert(asset, after: prevAsset)
            }
            
            play()
        }
        
        audioPlayer.seek(to: CMTime.zero)
    }
    
    func next() {
        if
            let asset = audioPlayer.currentItem,
            let trackIdx = trackAssets.firstIndex(of: asset)
        {
            if repeatMode == .off && trackIdx == trackAssets.count - 1 {
                return
            }
            
            pause()
            
            if repeatMode == .track {
                repeatMode = .list
                repeatOne()
            }
            
            if trackIdx + 1 == trackAssets.count {
                trackAssets.enumerated().forEach { idx, asset in
                    guard idx < trackAssets.count - 1 else {
                        return
                    }
                    
                    audioPlayer.insert(asset, after: nil)
                }
                
                audioPlayer.advanceToNextItem()
                audioPlayer.insert(trackAssets[trackAssets.count - 1], after: nil)
            } else {
                audioPlayer.advanceToNextItem()
            }
            
            play()
        }
        
        audioPlayer.seek(to: CMTime.zero)
    }
    
    func seek(_ seconds: Double) {
        audioPlayer.seek(to: CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func setNowPlaying() {
        if let track = currentTrack, let artwork = track.artwork {
            let nowPlayingCenter = MPNowPlayingInfoCenter.default()
            nowPlayingInfo = [
                MPMediaItemPropertyTitle: track.name,
                MPMediaItemPropertyAlbumTitle: track.albumName,
                MPMediaItemPropertyArtist: track.artist,
                MPMediaItemPropertyArtwork: MPMediaItemArtwork(boundsSize: artwork.size, requestHandler: { _ in artwork }),
                MPMediaItemPropertyPlaybackDuration: track.duration
            ]
            nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
        }
    }
    
    @Sendable func onElapsedTimeChange(time: CMTime)  {
        if !isEditing {
            elapsed = time.seconds
        }
    }
    
    @Sendable func onCurrentItemChange(player: AVQueuePlayer, change: NSKeyValueObservedChange<AVPlayerItem?>) {
        if let trackIdx = getCurrentIndex() {
            DispatchQueue.main.async {
                self.currentTrack = self.trackMetadata[trackIdx]
                self.setNowPlaying()
            }
        }
    }
    
    @objc func onAssetEnd(_ notification: NSNotification) {
        if let asset = notification.object as? AVPlayerItem {
            if repeatMode == .track {
                pause()
                audioPlayer.remove(asset)
                audioPlayer.insert(asset, after: nil)
                seek(0)
                play()
            } else if
                let trackIdx = getAssetIndex(asset),
                trackIdx == trackAssets.count - 1
            {
                pause()
                trackAssets.enumerated().forEach { idx, asset in
                    guard idx < trackAssets.count - 1 else {
                        return
                    }
                    
                    audioPlayer.insert(asset, after: nil)
                }
                
                audioPlayer.advanceToNextItem()
                audioPlayer.insert(trackAssets[trackAssets.count - 1], after: nil)
                
                audioPlayer.seek(to: CMTime.zero)
                
                if repeatMode == .list {
                    play()
                }
            }
        }
    }
    
    func loadTracks(list: MiniList, trackIdx: Int = 0, trackList: [MiniTrack], albums: [String: MiniList]) async {
        DispatchQueue.main.async {
            self.pause()
        }
        
        if listId == list.id {
            audioPlayer.removeAllItems()
            
            trackAssets[trackIdx ..< trackAssets.count].forEach { asset in
                audioPlayer.insert(asset, after: nil)
            }
            
            DispatchQueue.main.async {
                self.seek(0)
                self.play()
            }
            
            return
        }
        
        var metadata: [TrackMetadata] = []
        var assets: [AVPlayerItem] = []
        
        for track in trackList {
            if
                let album = albums[track.albumId],
                let (asset, metadatum) = try? await JellyfinAPI.shared.getAudioAsset(track: track, album: album, listName: list.name)
            {
                NotificationCenter.default.addObserver(self, selector: #selector(self.onAssetEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: asset)
                assets.append(asset)
                metadata.append(metadatum)
            }
        }
        
        trackAssets = assets
        trackMetadata = metadata
        
        DispatchQueue.main.async {
            self.listId = list.id
        }
        
        audioPlayer.removeAllItems()
        trackAssets[trackIdx ..< trackAssets.count].forEach { asset in
            audioPlayer.insert(asset, after: nil)
        }
        
        DispatchQueue.main.async {
            self.play()
        }
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off:
            repeatMode = .list
        case .list:
            repeatMode = .track
            repeatOne()
        case .track:
            repeatMode = .off
            repeatOne()
        }
    }
    
    func repeatOne() {
        if repeatMode == .track {
            audioPlayer.items().enumerated().forEach { idx, asset in
                guard idx > 0 else {
                    return
                }
                
                audioPlayer.remove(asset)
            }
        } else {
            guard let trackIdx = getCurrentIndex(), trackIdx < trackAssets.count - 1 else {
                return
            }
            
            trackAssets[trackIdx + 1 ..< trackAssets.count].forEach { asset in
                audioPlayer.insert(asset, after: nil)
            }
        }
    }
}
