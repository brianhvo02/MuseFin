//
//  Minis.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/10/23.
//

import Foundation

enum TrackDownloaded {
    case full
    case partial
    case none
}

struct MiniTrack {
    let id: String
    let name: String
    let artists: String
    let duration: Double
    let albumId: String
    var downloaded: TrackDownloaded
}

struct MiniList {
    let id: String
    let name: String
    let artist: String?
    let artwork: Data?
    let blurHash: String?
    
    init(id: String, name: String, artist: String? = nil, artwork: Data? = nil, blurHash: String? = nil) {
        self.id = id
        self.name = name
        self.artist = artist
        self.artwork = artwork
        self.blurHash = blurHash
    }
}

extension Dictionary {
   var jsonData: Data? {
      return try? JSONSerialization.data(withJSONObject: self)
   }
       
   func toJSONString() -> String? {
      if let jsonData = jsonData {
         let jsonString = String(data: jsonData, encoding: .utf8)
         return jsonString
      }
      return nil
   }
}
