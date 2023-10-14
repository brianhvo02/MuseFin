//
//  AlbumView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/3/23.
//

import SwiftUI
import AVKit
import SwiftData

struct AlbumView: View {
    @Query var offlineAlbums: [OfflineAlbum]
    @Query var users: [UserInfo]
    @Environment(\.modelContext) var ctx
    @ObservedObject var manager: AudioManager
    @State private var tracks: [MiniTrack] = []
    @State private var isDownloaded = false
    var album: MiniList
    
    func loadTracks(trackIdx: Int = 0) async {
        let connected = JellyfinAPI.isConnectedToNetwork()
        guard connected || tracks[trackIdx].downloaded == .full else {
            return
        }
        
        if connected {
            await manager.loadTracks(
                list: album,
                trackIdx: trackIdx,
                trackList: tracks,
                albums: [album.id: album]
            )
        } else {
            let downloadedTracks = tracks.filter { $0.downloaded == .full }
            
            await manager.loadTracks(
                list: album,
                trackIdx: downloadedTracks.firstIndex { $0.id == tracks[trackIdx].id } ?? 0,
                trackList: downloadedTracks,
                albums: [album.id: album]
            )
        }
    }
    
    init(manager: AudioManager, album: MiniList) {
        self.manager = manager
        self.album = album
        
        let albumId = album.id
        _offlineAlbums = Query(
            filter: #Predicate { $0.id == albumId },
            sort: []
        )
    }
    
    func onLoad() {
        isDownloaded = users[0].offlineLists.contains(album.id)
        
        Task {
            do {
                if JellyfinAPI.isConnectedToNetwork() {
                    let payload = try await JellyfinAPI.shared.getTracks(parentId: album.id, sortBy: ["SortName"])
                    tracks = payload.items.map { item in
                        var downloaded: TrackDownloaded  = .none
                        if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: item.id),
                           FileManager.default.fileExists(atPath: path) {
                            downloaded = .full
                        }
                        
                        return MiniTrack(
                            id: item.id,
                            name: item.name,
                            artists: item.artists.joined(separator: ", "),
                            duration: Double(item.runTimeTicks / 10000000),
                            albumId: item.albumId,
                            downloaded: downloaded
                        )
                    }
                } else {
                    guard offlineAlbums.indices.contains(0) else {
                        return
                    }
                    
                    let offlineTracks = offlineAlbums[0].tracks
                    tracks = offlineTracks.sorted { $0.trackNum < $1.trackNum }.map { track in
                        var downloaded: TrackDownloaded = .none
                        if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: track.id),
                           FileManager.default.fileExists(atPath: path) {
                            downloaded = .full
                        }
                        
                        return MiniTrack(
                            id: track.id,
                            name: track.name,
                            artists: track.artists,
                            duration: track.duration,
                            albumId: album.id,
                            downloaded: downloaded
                        )
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    var body: some View {
        NavScrollView(manager: manager) {
            VStack(alignment: .center, spacing: 16) {
                ListImage(list: album, width: 250, height: 250)
                
                VStack(spacing: 4) {
                    Text(album.name)
                        .font(.custom("Quicksand", size: 24))
                        .fontWeight(.bold)
                    Text(album.artist ?? "")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .multilineTextAlignment(.center)
            HStack {
                Button {
                    Task {
                        await loadTracks()
                    }
                } label: {
                    Image(systemName: "play.fill")
                    Text("Play")
                }
                .foregroundStyle(.accent)
                .frame(width: 160, height: 48)
                .background(.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Spacer()
                
                Button {
                    if let idx = tracks.indices.randomElement() {
                        manager.shuffle = true
                        Task {
                            await loadTracks(trackIdx: idx)
                        }
                    }
                } label: {
                    Image(systemName: "shuffle")
                    Text("Shuffle")
                }
                .foregroundStyle(.accent)
                .frame(width: 160, height: 48)
                .background(.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading) {
                Divider()
                if tracks.count > 0 {
                    ForEach(Array(tracks.enumerated()), id: \.offset) { idx, track in
                        Button(action: {
                            Task {
                                await loadTracks(trackIdx: idx)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Group {
                                    if manager.listId == album.id && manager.currentTrack?.id == track.id {
                                        Image(systemName: "chart.bar.xaxis")
                                            .symbolEffect(.pulse, options: .repeating, isActive: manager.isPlaying)
                                            .foregroundStyle(Color.accentColor)
                                    } else {
                                        Text(String(idx + 1))
                                            .foregroundStyle(Color.gray)
                                    }
                                }
                                .font(.system(size: 16))
                                .frame(width: 32, height: 16, alignment: .center)
                                
                                Text(track.name)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                switch track.downloaded {
                                case .full:
                                    Image(systemName: "arrow.down.circle")
                                case .partial:
                                    Image(systemName: "arrow.down.circle.dotted")
                                default: 
                                    EmptyView()
                                }
                            }
                            .foregroundStyle(JellyfinAPI.isConnectedToNetwork() || track.downloaded == .full ? .primaryText : .secondaryText)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if JellyfinAPI.isConnectedToNetwork() {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                if isDownloaded {
                                    let offlineAlbum = offlineAlbums[0]
                                    let offlineTracks = offlineAlbum.tracks
                                    if !offlineTracks.contains(where: { $0.playlists.count > 0 }) {
                                        for (idx, _) in tracks.enumerated() {
                                            if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: tracks[idx].id) {
                                                try? FileManager.default.removeItem(atPath: path)
                                                tracks[idx].downloaded = .none
                                            }
                                        }
                                        
                                        ctx.delete(offlineAlbum)
                                    }
                                    
                                    users[0].offlineLists.removeAll { $0 == album.id }
                                    
                                    isDownloaded = false
                                } else {
                                    if !offlineAlbums.indices.contains(0) {
                                        let offlineAlbum = OfflineAlbum(
                                            id: album.id,
                                            name: album.name,
                                            artist: album.artist!,
                                            blurHash: album.blurHash
                                        )
                                        
                                        do {
                                            guard let url = JellyfinAPI.shared.getItemImageUrl(itemId: album.id) else {
                                                return
                                            }
                                            let (data, _) = try await URLSession.shared.data(from: url)
                                            offlineAlbum.artwork = data
                                        } catch {
                                            print(error.localizedDescription)
                                        }
                                        
                                        let offlineTracks = tracks.enumerated().map { idx, track in
                                            return OfflineTrack(
                                                id: track.id,
                                                name: track.name,
                                                artists: track.artists,
                                                duration: track.duration,
                                                trackNum: idx + 1,
                                                album: offlineAlbum
                                            )
                                        }
                                        
                                        offlineTracks.forEach { ctx.insert($0) }
                                    }
                                    
                                    for (idx, _) in tracks.enumerated() {
                                        if tracks[idx].downloaded == .none {
                                            let trackId = tracks[idx].id
                                            Task {
                                                tracks[idx].downloaded = .partial
                                                try await JellyfinAPI.shared.downloadAudioAsset(trackId: trackId)
                                                tracks[idx].downloaded = .full
                                            }
                                        }
                                    }
                                    
                                    users[0].offlineLists.append(album.id)
                                    
                                    isDownloaded = true
                                }
                            }
                        } label: {
                            if isDownloaded {
                                HStack {
                                    Text("Remove from Downloads")
                                    Spacer()
                                    Image(systemName: "trash.fill")
                                }
                            } else {
                                HStack {
                                    Text("Download")
                                    Spacer()
                                    Image(systemName: "arrow.down.circle")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                    }
                }
            }
        }
        .onAppear(perform: onLoad)
    }
}
