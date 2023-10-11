//
//  PlaylistsView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/9/23.
//

import SwiftUI

struct PlaylistsView: View {
    @FetchRequest(sortDescriptors: []) var users: FetchedResults<UserInfo>
    @FetchRequest(sortDescriptors: [SortDescriptor(\.name)]) var offlinePlaylists: FetchedResults<OfflinePlaylist>
    @State private var playlists: [MiniList] = []
    @State private var error: String?
    @ObservedObject var manager: AudioManager
    @State private var searchText = ""
    
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
                    NavigationLink(destination: PlaylistView(manager: manager, playlist: playlist)) {
                        HStack(spacing: 16) {
                            ListImage(list: playlist, width: 48, height: 48)
                            
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
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Find in Playlists"
        )
        .onAppear {
            Task {
                if JellyfinAPI.isConnectedToNetwork() {
                    Task {
                        do {
                            let payload = try await JellyfinAPI.shared.getPlaylists()
                            playlists = payload.items.map { item in
                                return MiniList(
                                    id: item.id,
                                    name: item.name
                                )
                            }
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                } else {
                    playlists = offlinePlaylists.map { playlist in
                        return MiniList(
                            id: playlist.id ?? "",
                            name: playlist.name ?? "",
                            artwork: playlist.artwork
                        )
                    }
                }
            }
        }
    }
}
