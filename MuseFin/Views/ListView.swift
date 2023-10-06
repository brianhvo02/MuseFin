//
//  ListView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/3/23.
//

import SwiftUI
import AVKit
import NukeUI

enum ListData {
    case album(Album)
}

struct ListInfo {
    let imageUrl: URL?
    let id: String
    let name: String
    let artist: String?
}

struct ListView: View {
    let listData: ListData?
    @ObservedObject var manager: AudioManager
    @State private var error: String?
    @State private var listInfo: ListInfo?
    @State private var tracks: [Track] = []
    
    var body: some View {
        ZStack {
            Color("BackgroundColor").edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .center, spacing: 16) {
                    LazyImage(url: listInfo?.imageUrl) { image in
                        if let image = image.image {
                            image.resizable().aspectRatio(1, contentMode: .fit)
                        } else {
                            Image("LogoDark")
                        }
                    }
                    .frame(width: 300, height: 300)
                    Text(listInfo?.name ?? "")
                        .fontWeight(.bold)
                    Text(listInfo?.artist ?? "")
                        .foregroundStyle(Color.init("AccentColor"))
                }
                .multilineTextAlignment(.center)
                VStack(alignment: .leading) {
                    ForEach(Array(tracks.enumerated()), id: \.offset) { idx, track in
                        Button(action: { manager.loadTracks(listId: listInfo?.id ?? "", trackIdx: idx, trackList: tracks) }) {
                            HStack(spacing: 4) {
                                Group {
                                    if manager.listId == listInfo?.id, manager.curTrack == idx {
                                        Image(systemName: "chart.bar.xaxis")
                                            .symbolEffect(.pulse, options: .repeating, isActive: manager.isPlaying)
                                            .foregroundStyle(Color("AccentColor"))
                                    } else {
                                        Text(String(idx + 1))
                                            .foregroundStyle(Color.gray)
                                    }
                                }
                                .font(.system(size: 16))
                                .frame(width: 32, height: 16, alignment: .center)
                                
                                Text(track.name)
                            }
                            .padding(.all)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                            .overlay(.white)
                    }
                }
            }
        }
        .onAppear {
            switch listData {
            case let .album(album):
                listInfo = ListInfo(
                    imageUrl: JellyfinAPI.shared.getAlbumImageUrl(albumId: album.id),
                    id: album.id, name: album.name, artist: album.albumArtist
                )
                JellyfinAPI.shared.getTracks(parentId: album.id) { err, payload in
                    if let err = err {
                        error = err.localizedDescription
                    } else {
                        tracks = payload!.items
                    }
                }
            default: break
            }
        }
    }
}
