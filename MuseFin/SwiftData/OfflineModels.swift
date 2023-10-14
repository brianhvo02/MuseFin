//
//  OfflineModels.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/14/23.
//

import SwiftData
import Foundation

@Model class OfflineAlbum {
    @Attribute(.unique) let id: String
    let name: String
    let artist: String
    var artwork: Data?
    let blurHash: String?
    
    init(id: String, name: String, artist: String, artwork: Data? = nil, blurHash: String? = nil) {
        self.id = id
        self.name = name
        self.artist = artist
        self.artwork = artwork
        self.blurHash = blurHash
    }
    
    @Relationship(deleteRule: .cascade, inverse: \OfflineTrack.album) var tracks = [OfflineTrack]()
}

@Model class OfflinePlaylist {
    @Attribute(.unique) let id: String
    let name: String
    var artwork: Data?
    let trackOrder: [String: Int]
    
    init(id: String, name: String, artwork: Data? = nil, trackOrder: [String: Int]) {
        self.id = id
        self.name = name
        self.artwork = artwork
        self.trackOrder = trackOrder
    }
    
    @Relationship(deleteRule: .nullify, inverse: \OfflineTrack.playlists) var tracks = [OfflineTrack]()
}

@Model class OfflineTrack {
    @Attribute(.unique) let id: String
    let name: String
    let artists: String
    let duration: Double
    let trackNum: Int
    
    var playlists = [OfflinePlaylist]()
    let album: OfflineAlbum
    
    init(id: String, name: String, artists: String, duration: Double, trackNum: Int, album: OfflineAlbum) {
        self.id = id
        self.name = name
        self.artists = artists
        self.duration = duration
        self.trackNum = trackNum
        self.album = album
    }
}
