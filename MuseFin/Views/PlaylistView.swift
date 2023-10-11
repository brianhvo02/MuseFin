//
//  PlaylistView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/9/23.
//

import SwiftUI

struct PlaylistView: View {
    @FetchRequest var offlinePlaylists: FetchedResults<OfflinePlaylist>
    @FetchRequest(sortDescriptors: []) var users: FetchedResults<UserInfo>
    @Environment(\.managedObjectContext) var ctx
    @ObservedObject var manager: AudioManager
    @State private var albums: [String: MiniList] = [:]
    @State private var tracks: [MiniTrack] = []
    @State private var isDownloaded = false
    var playlist: MiniList
    
    init (manager: AudioManager, playlist: MiniList) {
        self.manager = manager
        self.playlist = playlist
        _offlinePlaylists = FetchRequest<OfflinePlaylist>(sortDescriptors: [], predicate: NSPredicate(format: "id == %@", playlist.id))
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
                        await manager.loadTracks(list: playlist, trackIdx: 0, trackList: tracks, albums: albums)
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
                            await manager.loadTracks(list: playlist, trackIdx: idx, trackList: tracks, albums: albums)
                        }
                    }) {
                        HStack(spacing: 12) {
                            if let album = albums[track.albumId] {
                                ListImage(list: album, width: 48, height: 48)
                                    .brightness(manager.list?.id == playlist.id && manager.currentTrack?.id == track.id ? -0.5 : 0)
                                    .overlay {
                                        if manager.list?.id == playlist.id && manager.currentTrack?.id == track.id {
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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task {
                            if isDownloaded {
                                let offlinePlaylist = offlinePlaylists[0]
                                
                                if let offlineTracks = offlinePlaylist.tracks?.allObjects as? [OfflineTrack] {
                                    for (idx, _) in offlineTracks.enumerated() {
                                        if
                                            let lists = users[0].offlineLists,
                                            let album = offlineTracks[idx].album,
                                            let albumId = album.id,
                                            !lists.contains(albumId),
                                            let playlists = offlineTracks[idx].playlists,
                                            !playlists.contains(where: { ($0 as! OfflinePlaylist).id != offlinePlaylist.id })
                                        {
                                            ctx.delete(album)
                                            
                                            if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: offlineTracks[idx].id) {
                                                try? FileManager.default.removeItem(atPath: path)
                                                tracks[idx].downloaded = .none
                                            }
                                        } else {
                                            offlinePlaylist.removeFromTracks(offlineTracks[idx])
                                        }
                                    }
                                }
                                
                                if let lists = users[0].offlineLists {
                                    var lists = lists.components(separatedBy: ",")
                                    lists.removeAll { $0 == playlist.id }
                                    users[0].offlineLists = lists.joined(separator: ",")
                                }
                                
                                ctx.delete(offlinePlaylist)
                                
                                try ctx.save()
                                isDownloaded = false
                            } else {
                                let offlinePlaylist = OfflinePlaylist(context: ctx)
                                offlinePlaylist.id = playlist.id
                                offlinePlaylist.name = playlist.name
                                offlinePlaylist.trackOrder = tracks.map{ $0.id }.joined(separator: ",")
                                
                                do {
                                    guard let url = JellyfinAPI.shared.getItemImageUrl(itemId: playlist.id) else {
                                        return
                                    }
                                    let (data, _) = try await URLSession.shared.data(from: url)
                                    offlinePlaylist.artwork = data
                                    
                                    for album in albums.values {
                                        if let lists = users[0].offlineLists, lists.contains(album.id) {
                                            continue
                                        }
                                        
                                        let offlineAlbum = OfflineAlbum(context: ctx)
                                        offlineAlbum.id = album.id
                                        offlineAlbum.name = album.name
                                        offlineAlbum.artist = album.artist
                                        offlineAlbum.blurHash = album.blurHash
                                        
                                        guard let url = JellyfinAPI.shared.getItemImageUrl(itemId: album.id) else {
                                            return
                                        }
                                        let (data, _) = try await URLSession.shared.data(from: url)
                                        offlineAlbum.artwork = data
                                        
                                        let trackData = try await JellyfinAPI.shared.getTracks(parentId: album.id, sortBy: ["SortName"])
                                        
                                        Array(trackData.items.enumerated()).forEach { idx, track in
                                            let offlineTrack = OfflineTrack(context: ctx)
                                            offlineTrack.album = offlineAlbum
                                            offlineTrack.id = track.id
                                            offlineTrack.name = track.name
                                            offlineTrack.artists = track.artists.joined(separator: ", ")
                                            offlineTrack.duration = Double(track.runTimeTicks / 10000000)
                                            offlineTrack.trackNum = Int16(idx + 1)
                                            
                                            if tracks.contains(where: { $0.id == track.id }) {
                                                offlinePlaylist.addToTracks(offlineTrack)
                                            }
                                        }
                                    }
                                    
                                    if let lists = users[0].offlineLists {
                                        users[0].offlineLists = lists + ",\(playlist.id)"
                                    }
                                    
                                    var trackOrderTemp: [String: Int] = [:]
                                    
                                    for (idx, _) in tracks.enumerated() {
                                        trackOrderTemp[tracks[idx].id] = idx
                                        if tracks[idx].downloaded == .none {
                                            let trackId = tracks[idx].id
                                            Task {
                                                tracks[idx].downloaded = .partial
                                                try await JellyfinAPI.shared.downloadAudioAsset(trackId: trackId)
                                                tracks[idx].downloaded = .full
                                            }
                                        }
                                    }
                                    
                                    if let trackOrder = trackOrderTemp.toJSONString() {
                                        offlinePlaylist.trackOrder = trackOrder
                                    }
                                    
                                    try ctx.save()
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
        .onAppear {
            if let lists = users[0].offlineLists {
                isDownloaded = lists.components(separatedBy: ",").contains { $0 == playlist.id }
            }
            
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
                        if
                            let offlinePlaylist = offlinePlaylists.first(where: { $0.id == playlist.id }),
                            let offlineTracks = offlinePlaylist.tracks?.allObjects as? [OfflineTrack],
                            let trackOrderRaw = offlinePlaylist.trackOrder,
                            let trackOrderData = trackOrderRaw.data(using: .utf8),
                            let trackOrder = try? JSONSerialization.jsonObject(with: trackOrderData, options: []) as? [String: Int]
                        {
                            tracks = offlineTracks.map { track in
                                if let album = track.album, let id = album.id {
                                    tempAlbums[id] = MiniList(
                                        id: album.id ?? "",
                                        name: album.name ?? "",
                                        artist: album.artist ?? "",
                                        artwork: album.artwork,
                                        blurHash: album.blurHash
                                    )
                                }
                                
                                var downloaded: TrackDownloaded  = .none
                                if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: track.id),
                                   FileManager.default.fileExists(atPath: path) {
                                    downloaded = .full
                                }
                                
                                return MiniTrack(
                                    id: track.id ?? "",
                                    name: track.name ?? "",
                                    artists: track.artists ?? "",
                                    duration: track.duration,
                                    albumId: track.album?.id ?? "",
                                    downloaded: downloaded
                                )
                            }
                            .sorted { trackOrder[$0.id] ?? 0 < trackOrder[$1.id] ?? 0 }
                        }
                    }
                    
                    albums = tempAlbums
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
}
