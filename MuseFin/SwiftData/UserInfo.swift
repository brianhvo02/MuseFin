//
//  UserInfo.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/13/23.
//

import SwiftData

@Model class UserInfo {
    var userId: String
    var offlineLists: [String]
    var serverUrl: String
    var token: String
    
    init(userId: String, offlineLists: [String], serverUrl: String, token: String) {
        self.userId = userId
        self.offlineLists = offlineLists
        self.serverUrl = serverUrl
        self.token = token
    }
}
