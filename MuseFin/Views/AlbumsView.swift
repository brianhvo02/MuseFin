//
//  AlbumsView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/3/23.
//

import SwiftUI
import NukeUI

struct AlbumsView: View {
    @FetchRequest(sortDescriptors: []) var users: FetchedResults<UserInfo>
    @State private var albums: [Album] = []
    @State private var error: String?
    @ObservedObject var manager: AudioManager
    
    let columns = [
        GridItem(.adaptive(minimum: 160))
    ]
    
    var body: some View {
        if let error = error {
            Text(error)
        }
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(albums, id: \.id) { album in
                    NavigationLink(destination: ListView(listData: .album(album), manager: manager)) {
                        VStack {
                            LazyImage(
                                url: JellyfinAPI.shared.getAlbumImageUrl(albumId: album.id)
                            ) { image in
                                if let image = image.image {
                                    image.resizable().aspectRatio(1, contentMode: .fit)
                                } else {
                                    Image("LogoDark")
                                }
                            }
                            .frame(width: 160, height: 160)
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
        .padding()
        .navigationTitle("Albums")
        .onAppear {
            JellyfinAPI.shared.getAlbums { err, payload in
                if let err = err {
                    error = err.localizedDescription
                } else {
                    albums = payload!.items
                }
            }
        }
    }
}
