//
//  Item.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/3/23.
//

import Foundation

protocol PItem: PBaseItem {
    var etag: String? { get set }
    var dateCreated: String { get set }
    var canDelete: Bool { get set }
    var canDownload: Bool { get set }
    var sortName: String { get set }
    var externalUrls: [String] { get set }
    var path: String { get set }
    var enableMediaSourceDisplay: Bool { get set }
    var taglines: [String] { get set }
    var genres: [String] { get set }
    var playAccess: String { get set }
    var remoteTrailers: [String] { get set }
    var parentId: String? { get set }
    var localTrailerCount: Int { get set }
    var childCount: Int { get set }
    var specialFeatureCount: Int { get set }
    var displayPreferencesId: String { get set }
    var primaryImageAspectRatio: Float { get set }
    var collectionType: String { get set }
}

struct Item: PItem {
    var name: String
    var serverId: String
    var id: String
    var etag: String?
    var dateCreated: String
    var canDelete: Bool
    var canDownload: Bool
    var sortName: String
    var externalUrls: [String]
    var path: String
    var enableMediaSourceDisplay: Bool
    var taglines: [String]
    var genres: [String]
    var playAccess: String
    var remoteTrailers: [String]
    var isFolder: Bool
    var parentId: String?
    var type: String
    var localTrailerCount: Int
    var userData: UserData
    var childCount: Int
    var specialFeatureCount: Int
    var displayPreferencesId: String
    var primaryImageAspectRatio: Float
    var collectionType: String
    var locationType: String
}

struct ItemContainer: Codable {
    let totalRecordCount: Int
    let startIndex: Int
    let items: [Item]
}
