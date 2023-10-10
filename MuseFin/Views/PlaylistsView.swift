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
    @State private var searchText = ""
    
    func getPlaylists() async {
        do {
            let payload = try await JellyfinAPI.shared.getPlaylists()
            playlists = payload.items
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    var body: some View {
        if let error = error {
            Text(error)
        }
        NavScrollView(manager: manager) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(
                    searchText.isEmpty ? playlists : playlists.filter { $0.name.lowercased().contains(searchText.lowercased()) },
                    id: \.id
                ) { playlist in
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
                                .font(.custom("Quicksand", size: 24))
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
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Find in Playlists"
        )
        .onAppear {
            Task {
                await getPlaylists()
            }
        }
    }
}
