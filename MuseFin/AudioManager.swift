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

enum ListType {
    case none
    case album(Album)
//    case playlist
}

class AudioManager: ObservableObject {
    var audioPlayer = QueuedAudioPlayer()
    var list: ListType = .none
    @Published var listId: String?
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var elapsed = 0.0
    @Published var duration = 0.0
    @Published var isEditing = false
    @Published var repeatMode: RepeatMode = .off
    var trackList: [Track] = []
    
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
                    self.duration = Double(track.runTimeTicks / 10000000)
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
    
    func loadTracks(listId: String, list: ListType, trackIdx: Int = 0, trackList: [Track]) async {
        if self.listId == listId {
            try? audioPlayer.jumpToItem(atIndex: trackIdx)
            return
        }
        
        self.trackList = trackList
        DispatchQueue.main.async {
            self.listId = listId
            self.list = list
        }
        
        audioPlayer.stop()
        
        var assets: [DefaultAudioItem] = []
        
        for track in trackList {
            let asset = await JellyfinAPI.shared.getAudioAsset(track: track)
            if let item = asset {
                assets.append(item)
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
