//
//  AlbumsView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/3/23.
//

import SwiftUI
import SwiftData

let alphabet = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
                "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
                "U", "V", "W", "X", "Y", "Z", "#"]

struct AlbumsView: View {
    @Query var users: [UserInfo]
    @Query(sort: [SortDescriptor(\OfflineAlbum.artist)]) var offlineAlbums: [OfflineAlbum]
    @State private var albums: [MiniList] = []
    @ObservedObject var manager: AudioManager
    @State private var searchText = ""
    @State private var sortedAlbums = [String: [MiniList]]()
    
    let columns = [
        GridItem(.adaptive(minimum: 160))
    ]
    
    func sortAlbums(albums: [MiniList]) {
        var sortedAlbumsTemp = [String: [MiniList]]()
        
        albums.forEach { album in
            guard let artist = album.artist, !artist.isEmpty && alphabet.contains(artist.first!.uppercased()) else {
                if sortedAlbumsTemp["#"] == nil {
                    sortedAlbumsTemp["#"] = []
                }
                sortedAlbumsTemp["#"]!.append(album)
                return
            }
            let letter = artist.first!.uppercased()
            if sortedAlbumsTemp[letter] == nil {
                sortedAlbumsTemp[letter] = []
            }
            sortedAlbumsTemp[letter]!.append(album)
        }
        
        sortedAlbums = sortedAlbumsTemp
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                NavScrollView(manager: manager) {
                    ForEach(alphabet, id: \.self) { letter in
                        if let filtered = sortedAlbums[letter] {
                            Section {
                                LazyVGrid(columns: columns, spacing: 20) {
                                    ForEach(filtered, id: \.id) { album in
                                        NavigationLink(destination: AlbumView(manager: manager, album: album)) {
                                            VStack {
                                                ListImage(list: album, width: 160, height: 160)
                                                
                                                Text(album.name)
                                                    .fontWeight(.bold)
                                                Text(album.artist ?? "")
                                                    .foregroundStyle(Color.gray)
                                            }
                                            .lineLimit(1)
                                        }
                                    }
                                }
                            } header: {
                                Text(letter)
                                    .font(.custom("Quicksand", size: 20))
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .id(letter)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                
                HStack{
                    Spacer()
                    VStack {
                        AlphabetScroller(proxy: proxy, titles: alphabet.filter { sortedAlbums.keys.contains($0) })
                    }
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Find in Albums"
        )
        .onChange(of: searchText, initial: true) {
            if albums.count > 0 {
                let filteredAlbums = searchText.isEmpty ? albums : albums.filter { $0.name.lowercased().contains(searchText.lowercased()) }
                sortAlbums(albums: filteredAlbums)
            }
        }
        .onAppear {
            if JellyfinAPI.isConnectedToNetwork() {
                Task {
                    do {
                        let payload = try await JellyfinAPI.shared.getAlbums()
                        albums = payload.items.map { item in
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
                        sortAlbums(albums: albums)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            } else {
                albums = offlineAlbums.map { album in
                    return MiniList(
                        id: album.id,
                        name: album.name,
                        artist: album.artist,
                        artwork: album.artwork,
                        blurHash: album.blurHash
                    )
                }
                sortAlbums(albums: albums)
            }
        }
    }
}
