//
//  MuseFinApp.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/2/23.
//

import SwiftUI
import SwiftData

@main
struct MuseFinApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .foregroundStyle(.primaryText)
                .font(.custom("Quicksand", size: 16))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.background)
        }
        .modelContainer(for: [
            UserInfo.self,
            OfflineAlbum.self,
            OfflinePlaylist.self,
            OfflineTrack.self
        ])
    }
}
