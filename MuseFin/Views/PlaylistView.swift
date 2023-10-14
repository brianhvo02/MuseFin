//
//  PlaylistView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/9/23.
//

import SwiftUI
import SwiftData

struct PlaylistView: View {
    @Query var offlinePlaylists: [OfflinePlaylist]
    @Query var offlineAlbums: [OfflineAlbum]
    @Query var users: [UserInfo]
    @Environment(\.modelContext) var ctx
    @ObservedObject var manager: AudioManager
    @State private var albums: [String: MiniList] = [:]
    @State private var tracks: [MiniTrack] = []
    @State private var isDownloaded = false
    var playlist: MiniList
    
    init(manager: AudioManager, playlist: MiniList) {
        self.manager = manager
        self.playlist = playlist
        
        let playlistId = playlist.id
        _offlinePlaylists = Query(
            filter: #Predicate { $0.id == playlistId },
            sort: []
        )

    }
    
    func onLoad() {
        isDownloaded = users[0].offlineLists.contains { $0 == playlist.id }
        
        Task {
            do {
                var tempAlbums: [String: MiniList] = [:]
                
                if JellyfinAPI.isConnectedToNetwork() {
                    let payload = try await JellyfinAPI.shared.getTracks(parentId: playlist.id)
                    tracks = payload.items.map { item in
                        var blurHash: String?
                        
                        if
                            let tag = item.albumPrimaryImageTag,
                            let hash = item.imageBlurHashes.Primary
                        {
                            blurHash = hash[tag]
                        }
                        
                        tempAlbums[item.albumId] = MiniList(
                            id: item.albumId,
                            name: item.album,
                            artist: item.albumArtist,
                            blurHash: blurHash
                        )
                        
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
                    let offlinePlaylist = offlinePlaylists[0]
                    let offlineTracks = offlinePlaylist.tracks
                    let trackOrder = offlinePlaylist.trackOrder
                    tracks = offlineTracks.map { track in
                        let album = track.album
                        tempAlbums[album.id] = MiniList(
                            id: album.id,
                            name: album.name,
                            artist: album.artist,
                            artwork: album.artwork,
                            blurHash: album.blurHash
                        )
                        
                        var downloaded: TrackDownloaded  = .none
                        if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: track.id),
                           FileManager.default.fileExists(atPath: path) {
                            downloaded = .full
                        }
                        
                        return MiniTrack(
                            id: track.id,
                            name: track.name,
                            artists: track.artists,
                            duration: track.duration,
                            albumId: track.album.id,
                            downloaded: downloaded
                        )
                    }
                    .sorted { trackOrder[$0.id] ?? 0 < trackOrder[$1.id] ?? 0 }
                }
                
                albums = tempAlbums
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func loadTracks(trackIdx: Int = 0) async {
        await manager.loadTracks(list: playlist, trackIdx: trackIdx, trackList: tracks, albums: albums)
    }
    
    var body: some View {
        NavScrollView(manager: manager) {
            VStack(alignment: .center, spacing: 16) {
                ListImage(list: playlist, width: 250, height: 250)
                
                Text(playlist.name)
                    .font(.custom("Quicksand", size: 24))
                    .fontWeight(.bold)
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
                ForEach(Array(tracks.enumerated()), id: \.offset) { idx, track in
                    Button(action: {
                        Task {
                            await loadTracks(trackIdx: idx)
                        }
                    }) {
                        HStack(spacing: 12) {
                            if let album = albums[track.albumId] {
                                ListImage(list: album, width: 48, height: 48)
                                    .brightness(manager.listId == playlist.id && manager.currentTrack?.id == track.id ? -0.5 : 0)
                                    .overlay {
                                        if manager.listId == playlist.id && manager.currentTrack?.id == track.id {
                                            Image(systemName: "chart.bar.xaxis")
                                                .symbolEffect(.pulse, options: .repeating, isActive: manager.isPlaying)
                                                .foregroundStyle(Color.secondaryText)
                                        }
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(track.name)
                                    .lineLimit(1)
                                Text(track.artists)
                                    .lineLimit(1)
                                    .foregroundStyle(.secondaryText)
                                    .font(.custom("Quicksand", size: 10))
                            }
                            
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
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
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
                                    let offlinePlaylist = offlinePlaylists[0]
                                    let offlineTracks = offlinePlaylist.tracks
                                    for (idx, _) in offlineTracks.enumerated() {
                                        let playlists = offlineTracks[idx].playlists
                                        let album = offlineTracks[idx].album
                                        if
                                            !users[0].offlineLists.contains(album.id),
                                            !playlists.contains(where: { $0.id != offlinePlaylist.id })
                                        {
                                            ctx.delete(album)
                                            
                                            if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: offlineTracks[idx].id) {
                                                try? FileManager.default.removeItem(atPath: path)
                                                tracks[idx].downloaded = .none
                                            }
                                        } else {
                                            offlinePlaylist.tracks.remove(at: idx)
                                        }
                                    }
                                    
                                    users[0].offlineLists.removeAll { $0 == playlist.id }
                                    ctx.delete(offlinePlaylist)
                                    
                                    isDownloaded = false
                                } else {
                                    let offlinePlaylist = OfflinePlaylist(
                                        id: playlist.id,
                                        name: playlist.name,
                                        trackOrder: tracks.enumerated().reduce([String: Int]()) { res, el in
                                            var dict = res
                                            let (idx, track) = el
                                            dict[track.id] = idx
                                            
                                            if track.downloaded == .none {
                                                let trackId = tracks[idx].id
                                                Task {
                                                    tracks[idx].downloaded = .partial
                                                    try await JellyfinAPI.shared.downloadAudioAsset(trackId: trackId)
                                                    tracks[idx].downloaded = .full
                                                }
                                            }
                                            
                                            return dict
                                        }
                                    )
                                    
                                    do {
                                        guard let url = JellyfinAPI.shared.getItemImageUrl(itemId: playlist.id) else {
                                            return
                                        }
                                        let (data, _) = try await URLSession.shared.data(from: url)
                                        offlinePlaylist.artwork = data
                                        
                                        var allOfflineTracks = [OfflineTrack]()
                                        
                                        for album in albums.values {
                                            if let offlineAlbum = offlineAlbums.first(where: { $0.id == album.id }) {
                                                offlineAlbum.tracks.forEach { offlineTrack in
                                                    if tracks.contains(where: { $0.id == offlineTrack.id }) {
                                                        print(true)
                                                        offlineTrack.playlists.append(offlinePlaylist)
                                                    }
                                                }
                                                
                                                continue
                                            }
                                            
                                            let offlineAlbum = OfflineAlbum(
                                                id: album.id,
                                                name: album.name,
                                                artist: album.artist!,
                                                blurHash: album.blurHash
                                            )
                                            
                                            guard let url = JellyfinAPI.shared.getItemImageUrl(itemId: album.id) else {
                                                continue
                                            }
                                            let (data, _) = try await URLSession.shared.data(from: url)
                                            offlineAlbum.artwork = data
                                            
                                            let trackData = try await JellyfinAPI.shared.getTracks(parentId: album.id, sortBy: ["SortName"])
                                            
                                            trackData.items.enumerated().forEach { idx, track in
                                                let offlineTrack = OfflineTrack(
                                                    id: track.id,
                                                    name: track.name,
                                                    artists: track.artists.joined(separator: ", "),
                                                    duration: Double(track.runTimeTicks / 10000000),
                                                    trackNum: idx + 1,
                                                    album: offlineAlbum
                                                )
                                                
                                                allOfflineTracks.append(offlineTrack)
                                            }
                                        }
                                        
                                        allOfflineTracks.forEach { offlineTrack in
                                            ctx.insert(offlineTrack)
                                            if tracks.contains(where: { $0.id == offlineTrack.id }) {
                                                offlineTrack.playlists.append(offlinePlaylist)
                                            }
                                        }
                                        
                                        users[0].offlineLists.append(playlist.id)
                                        
                                        isDownloaded = true
                                    } catch {
                                        print(error.localizedDescription)
                                    }
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
