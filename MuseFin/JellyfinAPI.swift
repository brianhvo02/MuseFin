//
//  JellyfinAPI.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/2/23.
//

import Foundation
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
    var user: User?
    var token: String?
    var serverUrl: URL?
    
    private init() {}
    
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
        user = result.user
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
        
        self.user = result
        self.token = user.token
        self.serverUrl = serverUrl
        
        return result
    }
    
    func getViews() async throws -> ItemContainer {
        guard let user = self.user else {
            throw LoginError.unauthorized
        }
        
        return try await request("/Users/\(user.id)/Views", contentType: ItemContainer.self)
    }
    
    func getChildren<T: Codable>(_ parentId: String, sortBy: [String], itemTypes: [String] = []) async throws -> T {
        guard let user = self.user else {
            throw LoginError.unauthorized
        }
        
        return try await request(
            "/Users/\(user.id)/Items",
            query: [
                "parentId": parentId,
                "includeItemTypes": itemTypes.joined(separator: ","),
                "recursive": "true",
                "sortBy": sortBy.joined(separator: ",")
            ],
            contentType: T.self
        )
    }
    
    func getItem<T: Codable>() async throws -> T {
        guard let user = self.user else {
            throw LoginError.unauthorized
        }
        
        return try await request("/Users/\(user.id)/Items", contentType: T.self)
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
    
    func getItemImageUrl(itemId: String) -> URL? {
        if var serverUrl = self.serverUrl {
            serverUrl.append(path: "/Items/\(itemId)/Images/Primary")
            return serverUrl
        }
        return nil
    }
    
    func getTracks(parentId: String, sortBy: [String] = []) async throws -> TrackContainer {
        return try await getChildren(parentId, sortBy: sortBy, itemTypes: ["Audio"])
    }
    
    func getAudioAsset(track: Track) async -> DefaultAudioItem? {
        guard let token = self.token, var serverUrl = self.serverUrl else {
            return nil
        }
        
        lazy var flacSupport = false
        
        #if targetEnvironment(simulator)
            flacSupport = true
        #endif
        
        serverUrl.append(path: "/Audio/\(track.id)/universal")
        serverUrl.append(queryItems: [
            URLQueryItem(name: "container", value: "mp3,aac,m4a|aac,m4b|aac\(flacSupport ? ",flac" : ""),webma,webm|webma"),
            URLQueryItem(name: "audioCodec", value: "aac"),
            URLQueryItem(name: "transcodingProtocol", value: "hls"),
            URLQueryItem(name: "transcodingContainer", value: "ts")
        ])
        
        var artwork = UIImage(named: "AppIconLight")
        
        if let artworkUrl = JellyfinAPI.shared.getItemImageUrl(itemId: track.albumId) {
            let result = try? await ImagePipeline.shared.image(for: artworkUrl)
            if let result = result {
                artwork = result
            }
        }
        
        return DefaultAudioItemAssetOptionsProviding(
            audioUrl: serverUrl.absoluteString,
            artist: track.artists.joined(separator: ", "),
            title: track.name, albumTitle: track.album,
            sourceType: .stream,
            artwork: artwork,
            options: [
                "AVURLAssetHTTPHeaderFieldsKey": [
                    "Authorization": "\(authHeader), Token=\"\(token)\""
                ]
            ]
        )
    }
    
    func downloadAudioAsset(trackId: Track) async {
        
    }
}
