//
//  List.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/14/23.
//

import CarPlay
import SwiftData
import Combine

enum ListType {
    case album
    case playlist
}

class List {
    var sections: [CPListSection]
    let template: CPListTemplate
    var cancellable : AnyCancellable?
    var currentTrack: TrackMetadata?
    
    required init(listType: ListType, sections: [CPListSection]) {
        self.sections = sections
        template = CPListTemplate(title: "Albums", sections: sections)
        
        if listType == .album {
            template.tabTitle = "Albums"
            template.tabImage = UIImage(systemName: "square.stack")
        } else {
            template.tabTitle = "Playlists"
            template.tabImage = UIImage(systemName: "music.note.list")
        }
        
        cancellable = AudioManager.shared
            .objectWillChange
            .receive(on: RunLoop.main)
            .sink { _ in
                if self.currentTrack?.id != AudioManager.shared.currentTrack?.id {
                    self.currentTrack = AudioManager.shared.currentTrack
                    
                    sections.forEach { section in
                        section.items.forEach { item in
                            if let item = item as? CPListItem {
                                let id = item.userInfo as? String
                                item.isPlaying = (
                                    id == AudioManager.shared.listId
                                        ||
                                    id == AudioManager.shared.currentTrack?.albumId
                                )
                            }
                        }
                    }
                    
                    self.template.updateSections(sections)
                }
            }
    }
    
    static func getList(
        lists: [MiniList],
        listType: ListType,
        trackOrder: [String: Int]? = nil,
        ctx: ModelContext?,
        interfaceController: CPInterfaceController
    ) -> List {
        var sortestLists = [String: [CPListItem]]()
        
        let items = lists.compactMap { list in
            let item = CPListItem(
                text: list.name,
                detailText: list.artist,
                image: nil,
                accessoryImage: UIImage(systemName: "chevron.right"),
                accessoryType: .disclosureIndicator
            )
            
            item.handler = { item, completion in
                if let ctx = ctx {
                    let template = TrackList.getTrackList(
                        list: list,
                        listType: listType,
                        ctx: ctx,
                        interfaceController: interfaceController
                    ).template
                    interfaceController.pushTemplate(template, animated: true) { _, _ in
                        completion()
                    }
                } else {
                    Task {
                        let template = await TrackList.getTrackList(
                            list: list,
                            listType: listType,
                            interfaceController: interfaceController
                        ).template
                        interfaceController.pushTemplate(template, animated: true) { _, _ in
                            completion()
                        }
                    }
                }
            }
            
            JellyfinAPI.shared.getListArtwork(list) { image in
                item.setImage(image)
            }
            
            item.userInfo = list.id
            item.isPlaying = (
                list.id == AudioManager.shared.listId
                    ||
                list.id == AudioManager.shared.currentTrack?.albumId
            )
            
            if listType == .album {
                guard let artist = list.artist, !artist.isEmpty && alphabet.contains(artist.first!.uppercased()) else {
                    if sortestLists["#"] == nil {
                        sortestLists["#"] = []
                    }
                    sortestLists["#"]!.append(item)
                    return item
                }
                
                let letter = artist.first!.uppercased()
                if sortestLists[letter] == nil {
                    sortestLists[letter] = []
                }
                sortestLists[letter]!.append(item)
            }
            
            return item
        }
        
        let sections = listType == .album
            ? alphabet.map { letter in
                return CPListSection(items: sortestLists[letter] ?? [CPListItem](), header: nil, sectionIndexTitle: letter)
            }
            : [CPListSection(items: items)]
        
        
        return self.init(listType: listType, sections: sections)
    }
    
    static func getAlbums(ctx: ModelContext, interfaceController: CPInterfaceController) -> List {
        guard let offlineAlbums = try? ctx.fetch(FetchDescriptor<OfflineAlbum>(sortBy: [SortDescriptor(\OfflineAlbum.artist)])) else {
            return self.init(listType: .album, sections: [])
        }
        
        let albums = offlineAlbums.map { album in
            return MiniList(
                id: album.id,
                name: album.name,
                artist: album.artist,
                artwork: album.artwork,
                blurHash: album.blurHash
            )
        }
        
        return getList(
            lists: albums,
            listType: .album,
            ctx: ctx,
            interfaceController: interfaceController
        )
    }
    
    static func getAlbums(interfaceController: CPInterfaceController) async -> List {
        guard let payload = try? await JellyfinAPI.shared.getAlbums() else {
            return self.init(listType: .album, sections: [])
        }
        
        let albums = payload.items.map { item in
            var blurHash: String? = nil
            if
                let tag = item.imageTags.Primary,
                let hash = item.imageBlurHashes.Primary
            {
                blurHash = hash[tag]
            }
            
            return MiniList(
                id: item.id,
                name: item.name,
                artist: item.albumArtist,
                blurHash: blurHash
            )
        }
        
        return getList(
            lists: albums,
            listType: .album,
            ctx: nil,
            interfaceController: interfaceController
        )
    }
    
    static func getPlaylists(ctx: ModelContext, interfaceController: CPInterfaceController) -> List {
        guard let offlinePlaylists = try? ctx.fetch(FetchDescriptor<OfflinePlaylist>(sortBy: [SortDescriptor(\OfflinePlaylist.name)])) else {
            return self.init(listType: .playlist, sections: [])
        }
        
        let playlists = offlinePlaylists.map { playlist in
            return MiniList(
                id: playlist.id,
                name: playlist.name,
                artwork: playlist.artwork
            )
        }
        
        return getList(
            lists: playlists,
            listType: .playlist,
            ctx: ctx,
            interfaceController: interfaceController
        )
    }
    
    static func getPlaylists(interfaceController: CPInterfaceController) async -> List {
        guard let payload = try? await JellyfinAPI.shared.getPlaylists() else {
            return self.init(listType: .playlist, sections: [])
        }
        
        let playlists = payload.items.map { item in
            return MiniList(
                id: item.id,
                name: item.name
            )
        }
        
        return getList(
            lists: playlists,
            listType: .playlist,
            ctx: nil,
            interfaceController: interfaceController
        )
    }
}
