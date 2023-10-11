//
//  AudioManager.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/4/23.
//

import Foundation
import SwiftAudioEx
import Nuke
import AVFAudio

class Player {
    static let shared = Player()
    var audioPlayer = QueuedAudioPlayer()
    
    private init() {}
}

class AudioManager: ObservableObject {
    var audioPlayer = Player.shared.audioPlayer
    var list: MiniList?
    @Published var currentTrack: MiniTrack?
    @Published var isPlaying = false
    @Published var elapsed = 0.0
    @Published var duration = 0.0
    @Published var isEditing = false
    @Published var repeatMode: RepeatMode = .off
    var trackList: [MiniTrack] = []
    var albumList: [String: MiniList] = [:]
    
    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        audioPlayer.remoteCommands = [
            .play,
            .pause,
            .changePlaybackPosition,
            .next,
            .previous,
        ]
        
        audioPlayer.event.queueIndex.addListener(self) { indices in
            DispatchQueue.main.async {
                if let idx = indices.newIndex {
                    let track = self.trackList[idx]
                    self.currentTrack = track
                    self.duration = track.duration
                }
            }
        }
        
        audioPlayer.event.stateChange.addListener(self) { state in
            DispatchQueue.main.async {
                switch state {
                case .playing:
                    self.isPlaying = true
                default:
                    self.isPlaying = false
                }
            }
        }
        
        audioPlayer.event.secondElapse.addListener(self) { data in
            DispatchQueue.main.async {
                if !self.isEditing {
                    self.elapsed = data
                }
            }
        }
    }
    
    func loadTracks(list: MiniList, trackIdx: Int = 0, trackList: [MiniTrack], albums: [String: MiniList]) async {
        if self.list?.id == list.id {
            try? audioPlayer.jumpToItem(atIndex: trackIdx)
            return
        }
        
        self.trackList = trackList
        self.albumList = albums
        DispatchQueue.main.async {
            self.list = list
        }
        
        audioPlayer.stop()
        
        var assets: [DefaultAudioItem] = []
        
        for track in self.trackList {
            if
                let list = albums[track.albumId],
                let asset = try? await JellyfinAPI.shared.getAudioAsset(track: track, list: list) 
            {
                assets.append(asset)
            }
        }
        
        try? audioPlayer.add(items: assets)
        try? audioPlayer.jumpToItem(atIndex: trackIdx, playWhenReady: true)
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off:
            repeatMode = .queue
        case .queue:
            repeatMode = .track
        case .track:
            repeatMode = .off
        }
        
        audioPlayer.repeatMode = repeatMode
    }
}
