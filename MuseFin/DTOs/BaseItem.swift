//
//  BaseItem.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/2/23.
//

import Foundation

protocol PBaseItem: Codable, Identifiable {
    var name: String { get set }
    var serverId: String { get set }
    var id: String { get set }
    var isFolder: Bool { get set }
    var type: String { get set }
    var userData: UserData { get set }
    var locationType: String { get set }
}

struct BaseItem: PBaseItem {
    var name: String
    var serverId: String
    var id: String
    var isFolder: Bool
    var type: String
    var userData: UserData
    var locationType: String
}

struct UserData: Codable {
    let playbackPositionTicks: Int
    let playCount: Int
    let isFavorite: Bool
    let played: Bool
    let key: String
}

struct ItemRef: Codable {
    let name: String
    let id: String
}
