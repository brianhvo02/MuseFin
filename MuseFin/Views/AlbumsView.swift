//
//  AlbumsView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/3/23.
//

import SwiftUI
import NukeUI

let alphabet = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
                "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
                "U", "V", "W", "X", "Y", "Z", "#"]

struct AlbumsView: View {
    @FetchRequest(sortDescriptors: []) var users: FetchedResults<UserInfo>
    @State private var albums: [Album] = []
    @State private var error: String?
    @ObservedObject var manager: AudioManager
    @State private var searchText = ""
    @State private var sortedAlbums = [String: [Album]]()
    
    let columns = [
        GridItem(.adaptive(minimum: 160))
    ]
    
    func getAlbums() async {
        do {
            let payload = try await JellyfinAPI.shared.getAlbums()
            albums = payload.items
            sortAlbums(albums: albums)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func sortAlbums(albums: [Album]) {
        var sortedAlbumsTemp = [String: [Album]]()
        
        albums.forEach { album in
            guard !album.albumArtist.isEmpty && alphabet.contains(album.albumArtist.first!.uppercased()) else {
                if sortedAlbumsTemp["#"] == nil {
                    sortedAlbumsTemp["#"] = []
                }
                sortedAlbumsTemp["#"]!.append(album)
                return
            }
            let letter = album.albumArtist.first!.uppercased()
            if sortedAlbumsTemp[letter] == nil {
                sortedAlbumsTemp[letter] = []
            }
            sortedAlbumsTemp[letter]!.append(album)
        }
        
        sortedAlbums = sortedAlbumsTemp
    }
    
    var body: some View {
        if let error = error {
            Text(error)
        }
        NavScrollView(manager: manager) {
            ForEach(alphabet, id: \.self) { letter in
                if let filtered = sortedAlbums[letter] {
                    Section(header: Text(letter)) {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filtered, id: \.id) { album in
                                NavigationLink(destination: AlbumView(album: album, manager: manager)) {
                                    VStack {
                                        LazyImage(
                                            url: JellyfinAPI.shared.getItemImageUrl(itemId: album.id)
                                        ) { image in
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
                                        .frame(width: 160, height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text(album.name)
                                            .fontWeight(.bold)
                                        Text(album.albumArtist)
                                            .foregroundStyle(Color.gray)
                                    }
                                    .lineLimit(1)
                                }
                            }
                        }
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
            let filteredAlbums = searchText.isEmpty ? albums : albums.filter { $0.name.lowercased().contains(searchText.lowercased()) }
            sortAlbums(albums: filteredAlbums)
        }
        .onAppear {
            Task {
                await getAlbums()
            }
        }
    }
}
