//
//  Album.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/3/23.
//

import Foundation

protocol PAlbum: PBaseItem {
    var premiereDate: String? { get set }
    var runTimeTicks: Int { get set }
    var productionYear: Int? { get set }
    var isFolder: Bool { get set }
    var artists: [String] { get set }
    var artistItems: [ItemRef] { get set }
    var albumArtist: String { get set }
    var albumArtists: [ItemRef] { get set }
}

struct Album: PAlbum {
    var name: String
    var serverId: String
    var id: String
    var type: String
    var userData: UserData
    var locationType: String
    var premiereDate: String?
    var runTimeTicks: Int
    var productionYear: Int?
    var isFolder: Bool
    var artists: [String]
    var artistItems: [ItemRef]
    var albumArtist: String
    var albumArtists: [ItemRef]
}

struct AlbumContainer: Codable {
    let totalRecordCount: Int
    let startIndex: Int
    let items: [Album]
}
