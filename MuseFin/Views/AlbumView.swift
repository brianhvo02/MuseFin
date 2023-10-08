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
                LazyImage(url: JellyfinAPI.shared.getAlbumImageUrl(albumId: album.id)) { image in
                    if let image = image.image {
                        image.resizable().aspectRatio(1, contentMode: .fit)
                    } else {
                        Image("LogoDark")
                    }
                }
                .frame(width: 300, height: 300)
                Text(album.name)
                    .fontWeight(.bold)
                Text(album.albumArtist)
                    .foregroundStyle(Color.accentColor)
            }
            .multilineTextAlignment(.center)
            VStack(alignment: .leading) {
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
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if idx < tracks.count - 1 {
                        Divider()
                            .overlay(.white)
                    }
                }
            }
            if let _ = manager.listId {
                Spacer()
                    .frame(height: 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            JellyfinAPI.shared.getTracks(parentId: album.id) { err, payload in
                if let err = err {
                    error = err.localizedDescription
                } else {
                    tracks = payload!.items
                }
            }
        }
    }
}
