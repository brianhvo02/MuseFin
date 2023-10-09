//
//  AlbumView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/3/23.
//

import SwiftUI
import AVKit
import NukeUI

struct AlbumView: View {
    var album: Album
    @ObservedObject var manager: AudioManager
    @State private var error: String?
    @State private var tracks: [Track] = []
    
    var body: some View {
        NavScrollView(manager: manager) {
            VStack(alignment: .center, spacing: 16) {
                LazyImage(url: JellyfinAPI.shared.getItemImageUrl(itemId: album.id)) { image in
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
                
                Text(album.name)
                    .fontWeight(.bold)
                Text(album.albumArtist)
                    .foregroundStyle(Color.accentColor)
            }
            .multilineTextAlignment(.center)
            HStack {
                Button {
                    Task {
                        await manager.loadTracks(listId: album.id, list: .album(album), trackIdx: 0, trackList: tracks)
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
                            await manager.loadTracks(listId: album.id, list: .album(album), trackIdx: idx, trackList: tracks)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Group {
                                if manager.listId == album.id && manager.currentTrack?.id == track.id {
                                    Image(systemName: "chart.bar.xaxis")
                                        .symbolEffect(.pulse, options: .repeating, isActive: manager.isPlaying)
                                        .foregroundStyle(Color.accentColor)
                                } else {
                                    Text(String(idx + 1))
                                        .foregroundStyle(Color.gray)
                                }
                            }
                            .font(.system(size: 16))
                            .frame(width: 32, height: 16, alignment: .center)
                            
                            Text(track.name)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            JellyfinAPI.shared.getTracks(parentId: album.id, sortByName: true) { err, payload in
                if let err = err {
                    error = err.localizedDescription
                } else {
                    tracks = payload!.items
                }
            }
        }
    }
}
