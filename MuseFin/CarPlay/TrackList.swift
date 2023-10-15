//
//  TrackList.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/14/23.
//

import CarPlay
import SwiftData
import Combine

class TrackList {
    let template: CPListTemplate
    var cancellable : AnyCancellable?
    var currentTrack: TrackMetadata?
    var listId: String
    
    required init(listId: String, title: String? = nil, sectionHeader: CPListSection? = nil, sectionBody: CPListSection? = nil) {
        self.listId = listId
        let sections = [sectionHeader, sectionBody].compactMap { $0 }
        self.template = CPListTemplate(title: title, sections: sections)
        cancellable = AudioManager.shared
            .objectWillChange
            .receive(on: RunLoop.main)
            .sink { _ in
                if self.currentTrack?.id != AudioManager.shared.currentTrack?.id {
                    self.currentTrack = AudioManager.shared.currentTrack
                    if let sectionBody = sectionBody {
                        sectionBody.items.forEach { item in
                            if let item = item as? CPListItem {
                                item.isPlaying = (
                                    (self.listId == AudioManager.shared.listId
                                        ||
                                     self.listId == AudioManager.shared.currentTrack?.albumId)
                                    && item.userInfo as? String == AudioManager.shared.currentTrack?.id
                                )
                            }
                        }
                        
                        self.template.updateSections([sectionHeader, sectionBody].compactMap { $0 })
                    }
                }
            }
    }
    
    static func getTrackList(
        list: MiniList,
        listType: ListType,
        tracks: [MiniTrack],
        albums: [String: MiniList],
        interfaceController: CPInterfaceController
    ) -> TrackList {
        let items = tracks.enumerated().map { idx, track in
            let item = CPListItem(
                text: track.name,
                detailText: nil,
                image: UIImage(systemName: "\(idx + 1).circle")
            )
            
            item.handler = { item, completion in
                let tracks = tracks
                Task {
                    await AudioManager.shared.loadTracks(
                        list: list,
                        trackIdx: idx,
                        trackList: tracks,
                        albums: albums
                    )
                }
                completion()
            }
            
            if listType == .playlist, let album = albums[track.albumId] {
                JellyfinAPI.shared.getListArtwork(album) { image in
                    item.setImage(image)
                }
            }
            
            item.userInfo = track.id
            item.isPlaying = (
                (list.id == AudioManager.shared.listId
                    ||
                 list.id == AudioManager.shared.currentTrack?.albumId)
                && track.id == AudioManager.shared.currentTrack?.id
            )
            
            if track.downloaded == .full {
                item.setAccessoryImage(UIImage(systemName: "arrow.down.circle"))
            }
            
            return item
        }
        
        let sectionHeader = CPListSection(
            items: [],
            header: list.name,
            headerSubtitle: "\(tracks.count) Song\(tracks.count > 1 ? "s" : "")",
            headerImage: nil,
            headerButton: nil,
            sectionIndexTitle: nil
        )
        
        JellyfinAPI.shared.getListArtwork(list) { image in
            sectionHeader.headerImage = image ?? UIImage(named: "LogoDark")
        }
        
        let sectionBody = CPListSection(items: items)
        
        if listType == .album {
            return self.init(listId: list.id, sectionHeader: sectionHeader, sectionBody: sectionBody)
        } else {
            return self.init(listId: list.id, title: list.name, sectionBody: sectionBody)
        }
        
    }
        
    static func getTrackList(
        list: MiniList,
        listType: ListType,
        ctx: ModelContext,
        interfaceController: CPInterfaceController
    ) -> TrackList {
        var albums: [String: MiniList] = [:]
        
        let listId = list.id
        guard
            let offlinePlaylists = try? ctx.fetch(
                FetchDescriptor<OfflinePlaylist>(
                    predicate: #Predicate {
                        $0.id == listId
                    }
                )
            )
        else {
            return self.init(listId: "")
        }
        
        guard let offlineTracks = try? ctx.fetch(FetchDescriptor<OfflineTrack>(sortBy: [SortDescriptor(\OfflineTrack.trackNum)])) else {
            return self.init(listId: "")
        }
        
        var tracks = offlineTracks.map { track in
            var downloaded: TrackDownloaded  = .none
            if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: track.id),
               FileManager.default.fileExists(atPath: path) {
                downloaded = .full
            }
            
            let album = track.album
            albums[album.id] = MiniList(
                id: album.id,
                name: album.name,
                artist: album.artist,
                artwork: album.artwork,
                blurHash: album.blurHash
            )
            
            return MiniTrack(
                id: track.id,
                name: track.name,
                artists: track.artists,
                duration: track.duration,
                albumId: track.album.id,
                downloaded: downloaded
            )
        }
        
        if listType == .playlist && !offlinePlaylists.isEmpty {
            let trackOrder = offlinePlaylists[0].trackOrder
            tracks.sort { trackOrder[$0.id] ?? 0 < trackOrder[$1.id] ?? 0 }
        }
        
        return getTrackList(
            list: list,
            listType: listType,
            tracks: tracks,
            albums: albums,
            interfaceController: interfaceController
        )
    }
    
    static func getTrackList(
        list: MiniList,
        listType: ListType,
        interfaceController: CPInterfaceController
    ) async -> TrackList {
        var albums: [String: MiniList] = [:]
        
        if let payload = try? await JellyfinAPI.shared.getTracks(
            parentId: list.id, 
            sortBy: listType == .album
                ? ["SortName"]
                : []
        ) {
            let tracks = payload.items.map { item in
                var downloaded: TrackDownloaded = .none
                if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: item.id),
                   FileManager.default.fileExists(atPath: path) {
                    downloaded = .full
                }
                
                var blurHash: String?
                
                if
                    let tag = item.albumPrimaryImageTag,
                    let hash = item.imageBlurHashes.Primary
                {
                    blurHash = hash[tag]
                }
                
                albums[item.albumId] = MiniList(
                    id: item.albumId,
                    name: item.album,
                    artist: item.albumArtist,
                    blurHash: blurHash
                )
                
                return MiniTrack(
                    id: item.id,
                    name: item.name,
                    artists: item.artists.joined(separator: ", "),
                    duration: Double(item.runTimeTicks / 10000000),
                    albumId: item.albumId,
                    downloaded: downloaded
                )
            }
            
            return getTrackList(
                list: list,
                listType: listType,
                tracks: tracks,
                albums: albums,
                interfaceController: interfaceController
            )
        }
        
        return self.init(listId: "")
    }
}
