//
//  PlaylistsView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/9/23.
//

import SwiftUI
import NukeUI

struct PlaylistsView: View {
    @FetchRequest(sortDescriptors: []) var users: FetchedResults<UserInfo>
    @State private var playlists: [Playlist] = []
    @State private var error: String?
    @ObservedObject var manager: AudioManager
    
    func getPlaylists() {
        JellyfinAPI.shared.getPlaylists { err, payload in
            if let err = err {
                error = err.localizedDescription
            } else {
                playlists = payload!.items
            }
        }
    }
    
    var body: some View {
        if let error = error {
            Text(error)
        }
        NavScrollView(manager: manager) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(playlists, id: \.id) { playlist in
                    NavigationLink(destination: PlaylistView(playlist: playlist, manager: manager)) {
                        HStack(spacing: 16) {
                            LazyImage(
                                url: JellyfinAPI.shared.getItemImageUrl(itemId: playlist.id)
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
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Text(playlist.name)
                                .fontWeight(.bold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondaryText)
                        }
                        .lineLimit(1)
                    }
                    Divider()
                }
            }
        }
        .onAppear {
            getPlaylists()
        }
    }
}
