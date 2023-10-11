//
//  ContentView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/4/23.
//

import SwiftUI
import Network

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
    @State private var path = NavigationPath()
    
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
                    if let track = manager.currentTrack, let album = manager.albumList[track.albumId] {
                        VStack {
                            Spacer()
                            HStack {
                                HStack(spacing: 16) {
                                    ListImage(list: album, width: 40, height: 40)
                                    
                                    Text(track.name)
                                        .lineLimit(1)
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
                                MusicPlayerView(showNowPlaying: $showNowPlaying, path: $path, manager: manager)
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
                    
                    guard JellyfinAPI.isConnectedToNetwork() else {
                        JellyfinAPI.shared.serverUrl = URL(string: users[0].serverUrl ?? "")
                        JellyfinAPI.shared.token = users[0].token
                        JellyfinAPI.shared.userId = users[0].id
                        loggedIn = true
                        return
                    }
                    
                    Task {
                        do {
                            let _ = try await JellyfinAPI.shared.tokenLogin(user: users[0])
                            loggedIn = true
                        } catch {
                            print(error.localizedDescription)
                            loggedIn = false
                        }
                    }
                }
        }
    }
}
