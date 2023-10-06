//
//  JellyfinAPI.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/2/23.
//

import Foundation
import AVFoundation

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
        completion: @escaping (LoginError?, T?) -> ()
    ) {
        guard let serverUrl = self.serverUrl ?? serverUrl else {
            completion(LoginError.notFound, nil)
            return
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
            request.httpBody = try! JSONEncoder().encode(body)
        }
        if let token = self.token ?? token {
            request.setValue("\(authHeader), Token=\"\(token)\"", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json; profile=\"CamelCase\"", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, res, err in
            do {
                guard err == nil else {
                    throw err!
                }
                let payload = try JSONDecoder().decode(T.self, from: data!)
                completion(nil, payload)
            } catch is URLError {
                completion(LoginError.notFound, nil)
            } catch {
                if let httpRes = res as? HTTPURLResponse {
                    if httpRes.statusCode == 401 {
                        completion(LoginError.unauthorized, nil)
                    } else {
                        print(error)
                        completion(LoginError.notFound, nil)
                    }
                } else {
                    print(err!)
                }
            }
        }
        .resume()
    }
    
    func login(serverUrl: URL, username: String, password: String, completion: @escaping (LoginError?, Login?) -> ()) {
        let payload = LoginPayload(username: username, pw: password)
        self.request(
            "/Users/AuthenticateByName",
            method: "POST", body: payload,
            serverUrl: serverUrl
        ) { (err, payload: Login?) in
            if let err = err {
                completion(err, nil)
                return
            }
            self.user = payload!.user
            self.token = payload!.accessToken
            self.serverUrl = serverUrl
            completion(nil, payload)
        }
    }
    
    func tokenLogin(user: UserInfo, completion: @escaping (LoginError?, User?) -> ()) {
        guard let serverAddr = user.serverUrl, let serverUrl = URL(string: serverAddr) else {
            completion(.notFound, nil)
            return
        }
        guard let token = user.token, let id = user.id else {
            completion(.unauthorized, nil)
            return
        }
        self.request(
            "/Users/Me",
            token: token, serverUrl: serverUrl
        ) { (err, payload: User?) in
            if let err = err {
                completion(err, nil)
                return
            }
            guard let payload = payload, payload.id == id else {
                completion(.unauthorized, nil)
                return
            }
            self.user = payload
            self.token = user.token
            self.serverUrl = serverUrl
            completion(nil, payload)
        }
    }
    
    func getViews(completion: @escaping (LoginError?, ItemContainer?) -> ()) {
        guard let user = self.user else {
            completion(.unauthorized, nil)
            return
        }
        
        self.request("/Users/\(user.id)/Views") { (err, payload: ItemContainer?) in
            if let err = err {
                completion(err, nil)
                return
            }
            completion(nil, payload)
        }
    }
    
    func getChildren<T: Codable>(_ parentId: String, itemTypes: [String] = [], completion: @escaping (LoginError?, T?) -> ()) {
        guard let user = self.user else {
            completion(.unauthorized, nil)
            return
        }
        
        self.request(
            "/Users/\(user.id)/Items",
            query: [
                "parentId": parentId,
                "includeItemTypes": itemTypes.joined(separator: ","),
                "recursive": "true",
                "sortBy": "SortName"
            ]
        ) { (err, payload: T?) in
            if let err = err {
                completion(err, nil)
                return
            }
            completion(nil, payload)
        }
    }
    
    func getItem<T: Codable>(completion: @escaping (LoginError?, T?) -> ()) {
        guard let user = self.user else {
            completion(.unauthorized, nil)
            return
        }
        
        self.request("/Users/\(user.id)/Items") { (err, payload: T?) in
            if let err = err {
                completion(err, nil)
                return
            }
            completion(nil, payload)
        }
    }
    
    func getAlbums(completion: @escaping (LoginError?, AlbumContainer?) -> ()) {
        self.getViews { err, views in
            if let err = err {
                completion(err, nil)
                return
            } else {
                let view = views!.items.first(where: { $0.collectionType == "music" })
                guard let view = view else {
                    completion(.notFound, nil)
                    return
                }
                self.getChildren(view.id, itemTypes: ["MusicAlbum"]) { (err, albums: AlbumContainer?) in
                    if let err = err {
                        completion(err, nil)
                        return
                    } else {
                        completion(nil, albums)
                    }
                }
            }
        }
    }
    
    func getAlbumImageUrl(albumId: String) -> URL? {
        if var serverUrl = self.serverUrl {
            serverUrl.append(path: "/Items/\(albumId)/Images/Primary")
            return serverUrl
        }
        return nil
    }
    
    func getTracks(parentId: String, completion: @escaping (LoginError?, TrackContainer?) -> ()) {
        self.getChildren(parentId, itemTypes: ["Audio"]) { (err, tracks: TrackContainer?) in
            if let err = err {
                completion(err, nil)
                return
            } else {
                completion(nil, tracks)
            }
        }
    }
    
    func getAudioAsset(trackId: String) -> AVPlayerItem? {
        if let token = self.token, var serverUrl = self.serverUrl {
            serverUrl.append(path: "/Audio/\(trackId)/universal")
            serverUrl.append(queryItems: [
                URLQueryItem(name: "container", value: "opus,webm|opus,mp3,aac,m4a|aac,m4b|aac,flac,webma,webm|webma,wav,ogg"),
                URLQueryItem(name: "transcodingProtocol", value: "hls")
            ])
            
            let asset = AVURLAsset(url: serverUrl, options: [
                "AVURLAssetHTTPHeaderFieldsKey": [
                    "Authorization": "\(authHeader), Token=\"\(token)\""
                ]
            ])
            
            return AVPlayerItem(asset: asset)
        }
        return nil
    }
}
