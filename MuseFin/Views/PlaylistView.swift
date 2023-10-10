//
//  PlaylistView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/9/23.
//

import SwiftUI
import NukeUI

struct PlaylistView: View {
    var playlist: Playlist
    @ObservedObject var manager: AudioManager
    @State private var error: String?
    @State private var tracks: [Track] = []
    
    var body: some View {
        NavScrollView(manager: manager) {
            VStack(alignment: .center, spacing: 16) {
                LazyImage(url: JellyfinAPI.shared.getItemImageUrl(itemId: playlist.id)) { image in
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
                
                Text(playlist.name)
                    .fontWeight(.bold)
            }
            .multilineTextAlignment(.center)
            HStack {
                Button {
                    Task {
                        await manager.loadTracks(listId: playlist.id, list: .playlist(playlist), trackIdx: 0, trackList: tracks)
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
                ForEach(Array(tracks.enumerated()), id: \.offset) { idx, track in
                    Button(action: {
                        Task {
                            await manager.loadTracks(listId: playlist.id, list: .playlist(playlist), trackIdx: idx, trackList: tracks)
                        }
                    }) {
                        HStack(spacing: 12) {
                            LazyImage(url: JellyfinAPI.shared.getItemImageUrl(itemId: track.albumId)) { image in
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
                            .brightness(manager.listId == playlist.id && manager.currentTrack?.id == track.id ? -0.5 : 0)
                            .overlay {
                                if manager.listId == playlist.id && manager.currentTrack?.id == track.id {
                                    Image(systemName: "chart.bar.xaxis")
                                        .symbolEffect(.pulse, options: .repeating, isActive: manager.isPlaying)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(track.name)
                                    .lineLimit(1)
                                Text(track.artists.joined(separator: ", "))
                                    .lineLimit(1)
                                    .foregroundStyle(.secondaryText)
                                    .font(.custom("Quicksand", size: 10))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                do {
                    let payload = try await JellyfinAPI.shared.getTracks(parentId: playlist.id)
                    tracks = payload.items
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}
