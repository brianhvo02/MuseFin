//
//  CarPlaySceneDelegate.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/13/23.
//

import CarPlay

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    var tracks: [MiniTrack] = []

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        
        Task {
            let listTemplate = CPListTemplate(title: "Albums", sections: await getAlbums())
            try await interfaceController.setRootTemplate(listTemplate, animated: true)
        }
    }
    
    private func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }
    
    func getAlbumList(_ album: MiniList) async -> CPListTemplate {
        tracks = []
        
        if JellyfinAPI.isConnectedToNetwork(),
           let payload = try? await JellyfinAPI.shared.getTracks(parentId: album.id, sortBy: ["SortName"])
        {
            let items = payload.items.enumerated().map { idx, item in
                var downloaded: TrackDownloaded  = .none
                if let path = JellyfinAPI.shared.getOfflineTrackPath(trackId: item.id),
                   FileManager.default.fileExists(atPath: path) {
                    downloaded = .full
                }
                
                let track = MiniTrack(
                    id: item.id,
                    name: item.name,
                    artists: item.artists.joined(separator: ", "),
                    duration: Double(item.runTimeTicks / 10000000),
                    albumId: item.albumId,
                    downloaded: downloaded
                )
                
                tracks.append(track)
                
                let item = CPListItem(
                    text: track.name,
                    detailText: nil,
                    image: UIImage(systemName: "\(idx + 1).circle")
                )
                
                item.handler = { item, completion in
                    Task {
                        await AudioManager.shared.loadTracks(
                            list: album,
                            trackIdx: idx,
                            trackList: self.tracks,
                            albums: [album.id: album]
                        )
                    }
                    completion()
                }
                
//                item.isPlaying = album.id == AudioManager.shared.listId && idx == AudioManager.shared.getCurrentIndex()
                if downloaded == .full {
                    item.setAccessoryImage(UIImage(systemName: "arrow.down.circle"))
                }
                
                return item
            }
            
            let section = CPListSection(
                items: items,
                header: album.name,
                headerSubtitle: "\(tracks.count) Song\(tracks.count > 1 ? "s" : "")",
                headerImage: await JellyfinAPI.shared.getAlbumArtwork(album),
                headerButton: nil,
                sectionIndexTitle: nil
            )
            
            return CPListTemplate(title: nil, sections: [section])
        }
        
        return CPListTemplate(title: nil, sections: [])
    }
    
    func getAlbums() async -> [CPListSection] {
        if JellyfinAPI.isConnectedToNetwork() {
            do {
                var sortedAlbums = [String: [CPListItem]]()
                let payload = try await JellyfinAPI.shared.getAlbums()
                payload.items.forEach { item in
                    var blurHash: String? = nil
                    if
                        let tag = item.imageTags.Primary,
                        let hash = item.imageBlurHashes.Primary
                    {
                        blurHash = hash[tag]
                    }
                    
                    let album = MiniList(
                        id: item.id,
                        name: item.name,
                        artist: item.albumArtist,
                        blurHash: blurHash
                    )
                    
                    let item = CPListItem(
                        text: album.name,
                        detailText: album.artist,
                        image: nil,
                        accessoryImage: UIImage(systemName: "chevron.right"),
                        accessoryType: .disclosureIndicator
                    )
                    
                    item.handler = { item, completion in
                        Task {
                            let template = await self.getAlbumList(album)
                            self.interfaceController?.pushTemplate(template, animated: true) { _, _ in
                                completion()
                            }
                        }
                    }
                    
                    JellyfinAPI.shared.getAlbumArtwork(album) { image in
                        item.setImage(image)
                    }
                    
//                    item.isPlaying = album.id == AudioManager.shared.listId
                    
                    guard let artist = album.artist, !artist.isEmpty && alphabet.contains(artist.first!.uppercased()) else {
                        if sortedAlbums["#"] == nil {
                            sortedAlbums["#"] = []
                        }
                        sortedAlbums["#"]!.append(item)
                        return
                    }
                    let letter = artist.first!.uppercased()
                    if sortedAlbums[letter] == nil {
                        sortedAlbums[letter] = []
                    }
                    sortedAlbums[letter]!.append(item)
                }
                
                return alphabet.map { letter in
                    return CPListSection(items: sortedAlbums[letter] ?? [CPListItem](), header: nil, sectionIndexTitle: letter)
                }
            } catch {
                print(error.localizedDescription)
            }
        } else {
//            lists = offlineAlbums.map { album in
//                return MiniList(
//                    id: album.id ?? "",
//                    name: album.name ?? "",
//                    artist: album.artist,
//                    artwork: album.artwork,
//                    blurHash: album.blurHash
//                )
//            }
        }
        
        return []
    }
}
