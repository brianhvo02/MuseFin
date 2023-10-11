//
//  AlbumView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/3/23.
//

import SwiftUI
import AVKit
import NukeUI

struct AlbumView: View {
    @FetchRequest var offlineAlbums: FetchedResults<OfflineAlbum>
    @FetchRequest(sortDescriptors: []) var users: FetchedResults<UserInfo>
    @Environment(\.managedObjectContext) var ctx
    @ObservedObject var manager: AudioManager
    @State private var tracks: [MiniTrack] = []
    @State private var isDownloaded = false
    var album: MiniList
    
    func loadTracks(trackIdx: Int) async {
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
    
    init (manager: AudioManager, album: MiniList) {
        self.manager = manager
        self.album = album
        _offlineAlbums = FetchRequest<OfflineAlbum>(sortDescriptors: [], predicate: NSPredicate(format: "id == %@", album.id))
    }
    
    var body: some View {
        NavScrollView(manager: manager) {
            VStack(alignment: .center, spacing: 16) {
                if JellyfinAPI.isConnectedToNetwork() {
                    LazyImage(url: JellyfinAPI.shared.getItemImageUrl(itemId: album.id)) { image in
                        if let image = image.image {
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                        } else {
                            Image("LogoDark")
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .frame(width: 250, height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if let artwork = album.artwork, let image = UIImage(data: artwork) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image("LogoDark")
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
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
                        await loadTracks(trackIdx: 0)
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
                if tracks.count > 0 {
                    ForEach(Array(tracks.enumerated()), id: \.offset) { idx, track in
                        Button(action: {
                            Task {
                                await loadTracks(trackIdx: idx)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Group {
                                    if manager.list?.id == album.id && manager.currentTrack?.id == track.id {
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
                                    if let offlineTracks = offlineAlbum.tracks?.allObjects as? [OfflineTrack],
                                       !offlineTracks.contains(where: { track in
                                           if let playlists = track.playlists, playlists.count > 0 {
                                               return true
                                           }
                                           
                                           return false
                                       })
                                    {
                                        for (idx, _) in tracks.enumerated() {
                                            if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: tracks[idx].id) {
                                                try? FileManager.default.removeItem(atPath: path)
                                                tracks[idx].downloaded = .none
                                            }
                                        }
                                        ctx.delete(offlineAlbum)
                                    }
                                    
                                    if let lists = users[0].offlineLists {
                                        var lists = lists.components(separatedBy: ",")
                                        lists.removeAll { $0 == album.id }
                                        users[0].offlineLists = lists.joined(separator: ",")
                                    }
                                    
                                    try ctx.save()
                                    isDownloaded = false
                                } else {
                                    if !offlineAlbums.indices.contains(0) {
                                        let offlineAlbum = OfflineAlbum(context: ctx)
                                        offlineAlbum.id = album.id
                                        offlineAlbum.name = album.name
                                        offlineAlbum.artist = album.artist
                                        offlineAlbum.blurHash = album.blurHash
                                        
                                        do {
                                            guard let url = JellyfinAPI.shared.getItemImageUrl(itemId: album.id) else {
                                                return
                                            }
                                            let (data, _) = try await URLSession.shared.data(from: url)
                                            offlineAlbum.artwork = data
                                        } catch {
                                            print(error.localizedDescription)
                                        }
                                        
                                        Array(tracks.enumerated()).forEach { idx, track in
                                            let offlineTrack = OfflineTrack(context: ctx)
                                            offlineTrack.album = offlineAlbum
                                            offlineTrack.id = track.id
                                            offlineTrack.name = track.name
                                            offlineTrack.artists = track.artists
                                            offlineTrack.duration = track.duration
                                            offlineTrack.trackNum = Int16(idx + 1)
                                        }
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
                                    
                                    if let lists = users[0].offlineLists {
                                        users[0].offlineLists = lists + ",\(album.id)"
                                    }
                                    
                                    try ctx.save()
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
        .onAppear {
            if let lists = users[0].offlineLists {
                isDownloaded = lists.contains(album.id)
            }
            
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
                        if
                            offlineAlbums.indices.contains(0),
                            let offlineTracks = offlineAlbums[0].tracks?.allObjects as? [OfflineTrack]
                        {
                            tracks = offlineTracks.sorted { $0.trackNum < $1.trackNum }.map { track in
                                var downloaded: TrackDownloaded = .none
                                if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: track.id),
                                   FileManager.default.fileExists(atPath: path) {
                                    downloaded = .full
                                }
                                
                                return MiniTrack(
                                    id: track.id ?? "",
                                    name: track.name ?? "",
                                    artists: track.artists ?? "",
                                    duration: track.duration,
                                    albumId: album.id,
                                    downloaded: downloaded
                                )
                            }
                        }
                    }
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
}
