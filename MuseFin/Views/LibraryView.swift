//
//  LibraryView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/2/23.
//

import SwiftUI

struct LibraryItem<Content: View>: View {
    let id: Views
    let display: String
    let icon: String
    @ViewBuilder let destination: Content
    
    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 24) {
                Image(systemName: icon)
                    .foregroundStyle(.accent)
                    .frame(width: 8, height: 8)
                Text(display)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondaryText)
            }
            .padding(.all)
        }
        
        Divider()
    }
}

struct LibraryView: View {
    @Binding var loggedIn: Bool?
    @Environment(\.managedObjectContext) var ctx
    @FetchRequest(sortDescriptors: []) var users: FetchedResults<UserInfo>
    @State private var views: [BaseItem] = []
    @State private var error: String?
    @ObservedObject var manager: AudioManager
    @State private var libraryItems: [Any] = []
    
    var body: some View {
        if let error = error {
            Text(error)
        }
        VStack(alignment: .leading) {
            Divider()
            
            LibraryItem(id: Views.playlists, display: "Playlists", icon: "music.note.list") {
                PlaylistsView(manager: manager)
                    .navigationTitle("Playlists")
            }
            LibraryItem(id: Views.artists, display: "Artists", icon: "music.mic") {
                EmptyView()
            }
            LibraryItem(id: Views.albums, display: "Albums", icon: "square.stack") {
                AlbumsView(manager: manager)
                    .navigationTitle("Albums")
            }
            LibraryItem(id: Views.songs, display: "Songs", icon: "music.note") {
                EmptyView()
            }
            LibraryItem(id: Views.downloaded, display: "Downloaded", icon: "arrow.down.circle") {
                EmptyView()
            }
            Button(action: {
                ctx.delete(users[0])
                try? ctx.save()
                loggedIn = false
            }) {
                HStack(spacing: 24) {
                    Image(systemName: "door.right.hand.open")
                        .foregroundStyle(.accent)
                        .frame(width: 8, height: 8)
                    Text("Log out")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondaryText)
                }
                .padding(.all)
            }
            
            Divider()
        }
        .font(.custom("Quicksand", size: 24))
    }
}
