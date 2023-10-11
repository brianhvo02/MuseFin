//
//  JellyfinAPI.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/2/23.
//

import Foundation
import SystemConfiguration
import UIKit
import SwiftAudioEx
import Nuke

var authHeader = "MediaBrowser Client=\"MuseFin\", Device=\"test\", DeviceId=\"test\", Version=\"0.0.0\""

enum LoginError: Error {
    case unauthorized
    case notFound
    case unexpected(code: Int)
}

extension LoginError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return NSLocalizedString("Incorrect username/password", comment: "Unauthorized")
        case .notFound:
            return NSLocalizedString("Server not found", comment: "Not Found")
        default:
            return NSLocalizedString("Unknown error", comment: "Unknown")
        }
    }
}

class JellyfinAPI {
    static let shared = JellyfinAPI()
    var userId: String?
    var token: String?
    var serverUrl: URL?
    var musicDirectory: URL
    
    private init() {
        let fm = FileManager.default
        musicDirectory = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        if !fm.fileExists(atPath: musicDirectory.path()) {
            try! fm.createDirectory(at: musicDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        fm.changeCurrentDirectoryPath(musicDirectory.path())
    }
    
    static func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }

        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        if flags.isEmpty {
            return false
        }

        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)

        return (isReachable && !needsConnection)
    }
    
    func request<T: Codable>(
        _ path: String, method: String? = nil,
        body: Codable? = nil, query: [String: String]? = nil,
        token: String? = nil, serverUrl: URL? = nil,
        contentType: T.Type
    ) async throws -> T {
        guard let serverUrl = self.serverUrl ?? serverUrl else {
            throw LoginError.notFound
        }
        var url = serverUrl.appending(path: path)
        if let query = query {
            let queryItems = query.map { URLQueryItem(name: $0, value: $1) }
            url.append(queryItems: queryItems)
        }
        var request = URLRequest(url: url)
        if let method = method {
            request.httpMethod = method
        }
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        if let token = self.token ?? token {
            request.setValue("\(authHeader), Token=\"\(token)\"", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json; profile=\"CamelCase\"", forHTTPHeaderField: "Accept")
        
        do {
            let (data, res) = try await URLSession.shared.data(for: request)
            let payload = try JSONDecoder().decode(T.self, from: data)
            
            if let res = res as? HTTPURLResponse {
                if res.statusCode == 401 {
                    throw LoginError.unauthorized
                }
                
                if res.statusCode == 200 {
                    return payload
                }
                
                throw LoginError.notFound
            }
            
            throw LoginError.notFound
        } catch is URLError {
            throw LoginError.notFound
        } catch {
            print(error)
            throw LoginError.unexpected(code: 99)
        }
    }
    
    func login(serverUrl: URL, username: String, password: String) async throws -> Login {
        let payload = LoginPayload(username: username, pw: password)
        let result = try await request(
            "/Users/AuthenticateByName",
            method: "POST", body: payload,
            serverUrl: serverUrl,
            contentType: Login.self
        )
        userId = result.user.id
        token = result.accessToken
        self.serverUrl = serverUrl
        
        return result
    }
    
    func tokenLogin(user: UserInfo) async throws -> User {
        guard let serverAddr = user.serverUrl, let serverUrl = URL(string: serverAddr) else {
            throw LoginError.notFound
        }
        
        guard let token = user.token, let id = user.id else {
            throw LoginError.unauthorized
        }
        
        let result = try await request(
            "/Users/Me",
            token: token, serverUrl: serverUrl,
            contentType: User.self
        )
        
        guard result.id == id else {
            throw LoginError.unauthorized
        }
        
        self.userId = result.id
        self.token = user.token
        self.serverUrl = serverUrl
        
        return result
    }
    
    func getViews() async throws -> ItemContainer {
        guard let userId = self.userId else {
            throw LoginError.unauthorized
        }
        
        return try await request("/Users/\(userId)/Views", contentType: ItemContainer.self)
    }
    
    func getChildren<T: Codable>(_ parentId: String, sortBy: [String], itemTypes: [String] = []) async throws -> T {
        guard let userId = userId else {
            throw LoginError.unauthorized
        }
        
        return try await request(
            "/Users/\(userId)/Items",
            query: [
                "parentId": parentId,
                "includeItemTypes": itemTypes.joined(separator: ","),
                "recursive": "true",
                "sortBy": sortBy.joined(separator: ",")
            ],
            contentType: T.self
        )
    }
    
    func getItem(itemId: String) async throws -> Item {
        guard let userId = userId else {
            throw LoginError.unauthorized
        }
        
        return try await request("/Users/\(userId)/Items/\(itemId)", contentType: Item.self)
    }
    
    func getAlbums() async throws -> AlbumContainer {
        let views = try await getViews()
        
        guard let view = views.items.first(where: { $0.collectionType == "music" }) else {
            throw LoginError.notFound
        }
        
        return try await getChildren(view.id, sortBy: ["AlbumArtist", "SortName"], itemTypes: ["MusicAlbum"])
    }
    
    func getPlaylists() async throws -> PlaylistContainer {
        let views = try await getViews()
        
        guard let view = views.items.first(where: { $0.collectionType == "playlists" }) else {
            throw LoginError.notFound
        }
        
        return try await getChildren(view.id, sortBy: ["SortName"])
    }
    
    func getItemImageUrl(itemId: String?) -> URL? {
        if let itemId = itemId, var serverUrl = self.serverUrl {
            serverUrl.append(path: "/Items/\(itemId)/Images/Primary")
            return serverUrl
        }
        return nil
    }
    
    func getTracks(parentId: String, sortBy: [String] = []) async throws -> TrackContainer {
        return try await getChildren(parentId, sortBy: sortBy, itemTypes: ["Audio"])
    }
    
    func getAudioAssetUrl(trackId: String, download: Bool = false) throws -> URL {
        guard var serverUrl = self.serverUrl else {
            throw LoginError.unauthorized
        }
        
        serverUrl.append(path: "/Audio/\(trackId)/universal")
        
        var sim: Bool?
        
        #if targetEnvironment(simulator)
        sim = true
        #endif
        
        if download {
            serverUrl.append(queryItems: [
                URLQueryItem(name: "audioCodec", value: "aac"),
                URLQueryItem(name: "transcodingContainer", value: "aac")
            ])
        } else {
            serverUrl.append(queryItems: [
                URLQueryItem(name: "container", value: "mp3,\(sim ?? false ? "aac,m4a|aac,m4b|aac,flac," : "")webma,webm|webma"),
                URLQueryItem(name: "audioCodec", value: "aac"),
                URLQueryItem(name: "transcodingProtocol", value: "hls")
            ])
        }
        
        return serverUrl
    }
    
    func getAudioAsset(track: MiniTrack, list: MiniList) async throws -> DefaultAudioItem {
        if JellyfinAPI.isConnectedToNetwork() {
            guard let _ = self.token else {
                throw LoginError.unauthorized
            }
        }
        
        var image = UIImage(named: "AppIconLight")
        
        if let artwork = list.artwork {
            image = UIImage(data: artwork)
        }
        
        if JellyfinAPI.isConnectedToNetwork(), let artworkUrl = JellyfinAPI.shared.getItemImageUrl(itemId: list.id) {
            if let result = try? await ImagePipeline.shared.image(for: artworkUrl) {
                image = result
            }
        }
        
        var path = URL(fileURLWithPath: track.id, relativeTo: musicDirectory)
            .appendingPathExtension("aac")
            .path
        var sourceType: SourceType = .file
        if !FileManager.default.fileExists(atPath: path) {
            print("grabbing from server")
            path = try! getAudioAssetUrl(trackId: track.id).absoluteString
            sourceType = .stream
        }
        
        return DefaultAudioItemAssetOptionsProviding(
            audioUrl: path,
            artist: track.artists,
            title: track.name, albumTitle: list.name,
            sourceType: sourceType,
            artwork: image,
            options: sourceType == .stream ? [
                "AVURLAssetHTTPHeaderFieldsKey": [
                    "Authorization": "\(authHeader), Token=\"\(token ?? "")\""
                ]
            ] : [:]
        )
    }
    
    func downloadAudioAsset(trackId: String) async throws {
        guard let token = self.token else {
            throw LoginError.unauthorized
        }
        
        if FileManager.default.fileExists(atPath: trackId) {
            return
        }
        
        let url = try getAudioAssetUrl(trackId: trackId, download: true)
        var request = URLRequest(url: url)
        request.setValue("\(authHeader), Token=\"\(token)\"", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, res) = try await URLSession.shared.data(for: request)
            
            if let res = res as? HTTPURLResponse {
                if res.statusCode == 401 {
                    throw LoginError.unauthorized
                }
                
                if res.statusCode == 200 {
                    try data.write(to: URL(fileURLWithPath: trackId, relativeTo: musicDirectory).appendingPathExtension("aac"))
                    print("download success")
                    return
                }
                
                throw LoginError.notFound
            }
        } catch is URLError {
            throw LoginError.notFound
        } catch {
            print(error)
            throw LoginError.unexpected(code: 99)
        }
    }
    
    func getOfflineTrackPath(trackId: String?) -> String? {
        guard let trackId = trackId else {
            return nil
        }
        
        return URL(
            fileURLWithPath: trackId,
            relativeTo: musicDirectory
        )
        .appendingPathExtension("aac")
        .path
    }
}
