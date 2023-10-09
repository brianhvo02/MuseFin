//
//  Playlist.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/9/23.
//

import Foundation

struct Playlist: PBaseItem {
    var name: String
    var serverId: String
    var id: String
    var type: String
    var userData: UserData
    var locationType: String
    var isFolder: Bool
}

struct PlaylistContainer: Codable {
    let totalRecordCount: Int
    let startIndex: Int
    let items: [Playlist]
}
