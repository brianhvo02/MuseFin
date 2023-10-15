//
//  AudioManager.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/4/23.
//

import UIKit
import AVFoundation
import MediaPlayer
import CarPlay

struct TrackMetadata {
    let id: String
    let name: String
    let albumId: String
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
    @Published var shuffle = false
    
    var trackAssets: [AVPlayerItem] = []
    var shuffledAssets: [AVPlayerItem] = []
    var trackMetadata: [TrackMetadata] = []
    var assetObservers: [NSKeyValueObservation] = []
    var playerElapsedTimeObserver: Any?
    var playerCurrentItemObserver: NSKeyValueObservation?
    var nowPlayingInfo: [String: Any] = [:]
    
    var cpShuffleButton: CPNowPlayingImageButton?
    var cpRepeatButton: CPNowPlayingImageButton?
    
    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        
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
             changeHandler: onCurrentItemChange
        )
        
        playerElapsedTimeObserver = audioPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: DispatchQueue.main,
            using: onElapsedTimeChange
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    @objc func handleInterruption(notification: Notification) {
        guard 
            let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) 
        else {
            return
        }

        switch type {
        case .began:
            pause()

        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                play()
            }
        default: break
        }
    }
    
    func getAssetIndex(_ asset: AVPlayerItem) -> Int? {
        return getAssets().firstIndex(of: asset)
    }
    
    func getCurrentIndex() -> Int? {
        guard let asset = audioPlayer.currentItem else {
            return nil
        }
        
        return getAssetIndex(asset)
    }
    
    func play() {
        try? AVAudioSession.sharedInstance().setActive(true)
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
            let trackIdx = getAssetIndex(asset)
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
                if let lastAsset = getAssets().last {
                    audioPlayer.removeAllItems()
                    addToQueue(asset: lastAsset)
                }
            } else {
                let prevAsset = getAssets()[trackIdx - 1]
                audioPlayer.replaceCurrentItem(with: prevAsset)
                audioPlayer.insert(asset, after: prevAsset)
            }
            
            play()
        }
    }
    
    func next() {
        if
            let asset = audioPlayer.currentItem,
            let trackIdx = getAssets().firstIndex(of: asset)
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
                addToQueue(assets: getAssets(), to: trackAssets.count - 1)
                audioPlayer.advanceToNextItem()
                addToQueue(asset: getAssets().last)
            } else {
                audioPlayer.advanceToNextItem()
            }
            
            play()
        }
    }
    
    func clearQueue() {
        audioPlayer.items().enumerated().forEach { idx, asset in
            guard idx > 0 else {
                return
            }
            
            audioPlayer.remove(asset)
        }
    }
    
    func addToQueue(asset: AVPlayerItem?) {
        guard let asset = asset else {
            return
        }
        
        audioPlayer.insert(asset, after: nil)
    }
    
    func addToQueue(assets: [AVPlayerItem], from: Int? = nil, to: Int? = nil) {
        (
            from == 0 && to == nil
                ? assets
                : Array(
                    assets[
                        (from ?? 0) ..< (to ?? assets.count)
                    ]
                )
        )
        .forEach { asset in
            audioPlayer.insert(asset, after: nil)
        }
    }
    
    func toggleShuffle() {
        guard let currentAsset = audioPlayer.currentItem else {
            return
        }
        
        shuffle.toggle()
        cpShuffleButton?.isSelected = shuffle
        
        if shuffle {
            let shuffled = trackAssets.filter { $0 != currentAsset }.shuffled()
            
            shuffledAssets = [currentAsset]
            shuffledAssets.append(contentsOf: shuffled)
            
            if repeatMode != .track {
                clearQueue()
                addToQueue(assets: shuffled)
            }
        } else {
            guard let trackIdx = getAssetIndex(currentAsset), repeatMode != .track else {
                return
            }
            
            clearQueue()
            addToQueue(assets: trackAssets, from: trackIdx + 1)
        }
    }
    
    func getAssets() -> [AVPlayerItem] {
        return shuffle ? shuffledAssets : trackAssets
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
        if
            let asset = player.currentItem,
            let trackIdx = trackAssets.firstIndex(of: asset)
        {
            player.seek(to: CMTime.zero)
            DispatchQueue.main.async {
                self.currentTrack = self.trackMetadata[trackIdx]
                self.setNowPlaying()
            }
        }
    }
    
    @Sendable func onAssetLoad(asset: AVPlayerItem, change: NSKeyValueObservedChange<AVPlayerItem.Status>) {
        if asset.status == .readyToPlay {
            self.play()
        }
    }
    
    @objc func onAssetEnd(_ notification: NSNotification) {
        if let asset = notification.object as? AVPlayerItem {
            if repeatMode == .track {
                pause()
                audioPlayer.remove(asset)
                addToQueue(asset: asset)
                seek(0)
                play()
            } else if
                let trackIdx = getAssetIndex(asset),
                trackIdx == trackAssets.count - 1
            {
                pause()
                
                addToQueue(assets: getAssets(), to: trackAssets.count - 1)
                audioPlayer.advanceToNextItem()
                addToQueue(asset: getAssets().last)
                
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
        
        let wasShuffled = shuffle
        
        DispatchQueue.main.async {
            self.shuffle = false
        }
        
        if listId == list.id {
            audioPlayer.removeAllItems()
            
            addToQueue(assets: trackAssets, from: trackIdx)
            
            DispatchQueue.main.async {
                if wasShuffled {
                    self.toggleShuffle()
                }
                self.play()
            }
            
            return
        }
        
        var metadata: [TrackMetadata] = []
        var assets: [AVPlayerItem] = []
        var assetObservers: [NSKeyValueObservation] = []
        
        for track in trackList {
            if
                let album = albums[track.albumId],
                let (asset, metadatum) = try? await JellyfinAPI.shared.getAudioAsset(track: track, album: album, listName: list.name)
            {
                NotificationCenter.default.addObserver(self, selector: #selector(self.onAssetEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: asset)
                let assetObserver = asset.observe(
                    \.status,
                     options:  [.new, .old],
                     changeHandler: self.onAssetLoad
                )
                assets.append(asset)
                metadata.append(metadatum)
                assetObservers.append(assetObserver)
            }
        }
        
        trackAssets = assets
        trackMetadata = metadata
        self.assetObservers = assetObservers
        
        DispatchQueue.main.async {
            self.listId = list.id
        }
        
        audioPlayer.removeAllItems()
        addToQueue(assets: trackAssets, from: trackIdx)
        
        DispatchQueue.main.async {
            if wasShuffled {
                self.toggleShuffle()
            }
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
            clearQueue()
        } else {
            guard let trackIdx = getCurrentIndex(), trackIdx < trackAssets.count - 1 else {
                return
            }
            
            addToQueue(assets: getAssets(), from: trackIdx + 1)
        }
    }
}
