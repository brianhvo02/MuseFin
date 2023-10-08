//
//  ContentView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/4/23.
//

import SwiftUI
import NukeUI

enum Views {
    case library
    case playlists
    case artists
    case albums
    case songs
    case downloaded
}

struct ContentView: View {
    @FetchRequest(sortDescriptors: []) var users: FetchedResults<UserInfo>
    @State private var loggedIn: Bool?
    @StateObject private var manager = AudioManager()
    @State private var showNowPlaying = false
    @State var path = NavigationPath()
    
    var body: some View {
        if let loggedIn = loggedIn {
            if loggedIn {
                ZStack {
                    NavigationStack(path: $path) {
                        NavScrollView(manager: manager) {
                            LibraryView(loggedIn: $loggedIn, manager: manager)
                                .navigationTitle("Library")
                        }
                    }
                    if let track = manager.currentTrack {
                        VStack {
                            Spacer()
                            HStack {
                                HStack {
                                    LazyImage(url: JellyfinAPI.shared.getAlbumImageUrl(albumId: track.albumId)) { image in
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
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    Text(track.name)
                                        .font(.custom("Quicksand", size: 20))
                                }
                                Spacer()
                                HStack(spacing: 16) {
                                    Button {
                                        if manager.isPlaying {
                                            manager.audioPlayer.pause()
                                        } else {
                                            manager.audioPlayer.play()
                                        }
                                    } label: {
                                        Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 20))
                                    }
                                    Button {
                                        try? manager.audioPlayer.next()
                                    } label: {
                                        Image(systemName: "forward.fill")
                                            .font(.system(size: 20))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: 64)
                            .padding(.horizontal)
                            .background(
                                Color(.secondaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            )
                            .padding(.all)
                            .onTapGesture {
                                showNowPlaying.toggle()
                            }
                            .fullScreenCover(isPresented: $showNowPlaying) {
                                MusicPlayer(showNowPlaying: $showNowPlaying, path: $path, manager: manager)
                            }
                        }
                    }
                }
            } else {
                LoginView(loggedIn: $loggedIn)
            }
        } else {
            Spacer()
                .onAppear {
                    guard users.indices.contains(0) else {
                        loggedIn = false
                        return
                    }
                    JellyfinAPI.shared.tokenLogin(user: users[0]) { err, user in
                        if (err == nil) {
                            loggedIn = true
                        } else {
                            loggedIn = false
                        }
                    }
                }
        }
    }
}
