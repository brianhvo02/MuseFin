//
//  Track.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/3/23.
//

import Foundation

protocol PTrack: PBaseItem {
    var runTimeTicks: Int { get set }
    var indexNumber: Int { get set }
    var isFolder: Bool { get set }
    var artists: [String] { get set }
    var artistItems: [ItemRef] { get set }
    var album: String { get set }
    var albumId: String { get set }
    var albumArtist: String { get set }
    var albumArtists: [ItemRef] { get set }
}

struct Track: PTrack {
    var name: String
    var serverId: String
    var id: String
    var type: String
    var userData: UserData
    var locationType: String
    var runTimeTicks: Int
    var indexNumber: Int
    var isFolder: Bool
    var artists: [String]
    var artistItems: [ItemRef]
    var album: String
    var albumId: String
    var albumArtist: String
    var albumArtists: [ItemRef]
}

struct TrackContainer: Codable {
    let totalRecordCount: Int
    let startIndex: Int
    let items: [Track]
}
