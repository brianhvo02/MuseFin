//
//  ContentView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/4/23.
//

import SwiftUI

enum Views {
    case loading
    case login
    
    case library
    case playlists
    case artists
    case albums
    case songs
    case downloaded
    
    case list
}

struct ContentView: View {
    @FetchRequest(sortDescriptors: []) var users: FetchedResults<UserInfo>
    @State private var loggedIn: Bool?
    @StateObject private var manager = AudioManager()
    
    var body: some View {
        if let loggedIn = loggedIn {
            if loggedIn {
                VStack {
                    NavigationView {
                        ZStack {
                            Color("BackgroundColor").edgesIgnoringSafeArea(.all)
                            ScrollView {
                                LibraryView(loggedIn: $loggedIn, manager: manager)
                                    .navigationTitle("Library")
                            }
                        }
                    }
                    .navigationViewStyle(.stack)
//                    HStack {
//                        
//                    }
//                    .frame(maxWidth: .infinity, maxHeight: 24)
//                    .background(Color.white)
//                    .padding(.all)
                }
            } else {
                LoginView(loggedIn: $loggedIn)
            }
        } else {
            Text("")
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
