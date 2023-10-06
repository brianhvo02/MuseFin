//
//  Login.swift
//  MuseFin
//
//  Created by Brian Huy Vo on Int/Int/Int.
//

import Foundation

struct LoginPayload: Codable {
    let username: String
    let pw: String
}

struct Login: Codable {
    let user: User
    let sessionInfo: SessionInfo
    let accessToken: String
    let serverId: String
}

struct User: Codable {
    let name: String
    let serverId: String
    let id: String
    let hasPassword: Bool
    let hasConfiguredPassword: Bool
    let hasConfiguredEasyPassword: Bool
    let enableAutoLogin: Bool
    let lastLoginDate: String
    let lastActivityDate: String
    let configuration: UserConfig
    let policy: UserPolicy
}

struct UserConfig: Codable {
    let playDefaultAudioTrack: Bool
    let subtitleLanguagePreference: String
    let displayMissingEpisodes: Bool
//    let groupedFolders: [],
    let subtitleMode: String
    let displayCollectionsView: Bool
    let enableLocalPassword: Bool
//    let orderedViews: [],
//    let latestItemsExcludes: [],
//    let myMediaExcludes: [],
    let hidePlayedInLatest: Bool
    let rememberAudioSelections: Bool
    let rememberSubtitleSelections: Bool
    let enableNextEpisodeAutoPlay: Bool
}

struct UserPolicy: Codable {
    let isAdministrator: Bool
    let isHidden: Bool
    let isDisabled: Bool
//    let blockedTags: [],
    let enableUserPreferenceAccess: Bool
//    let accessSchedules: [],
//    let blockUnratedItems: [],
    let enableRemoteControlOfOtherUsers: Bool
    let enableSharedDeviceControl: Bool
    let enableRemoteAccess: Bool
    let enableLiveTvManagement: Bool
    let enableLiveTvAccess: Bool
    let enableMediaPlayback: Bool
    let enableAudioPlaybackTranscoding: Bool
    let enableVideoPlaybackTranscoding: Bool
    let enablePlaybackRemuxing: Bool
    let forceRemoteSourceTranscoding: Bool
    let enableContentDeletion: Bool
//    let enableContentDeletionFromFolders: [],
    let enableContentDownloading: Bool
    let enableSyncTranscoding: Bool
    let enableMediaConversion: Bool
//    let enabledDevices: [],
    let enableAllDevices: Bool
//    let enabledChannels: [],
    let enableAllChannels: Bool
//    let enabledFolders: [],
    let enableAllFolders: Bool
    let invalidLoginAttemptCount: Int
    let loginAttemptsBeforeLockout: Int
    let maxActiveSessions: Int
    let enablePublicSharing: Bool
//    let blockedMediaFolders: [],
//    let blockedChannels: [],
    let remoteClientBitrateLimit: Int
    let authenticationProviderId: String
    let passwordResetProviderId: String
    let syncPlayAccess: String
}

struct SessionInfo: Codable {
    let playState: SessionPlayState
//    let additionalUsers: [],
    let capabilities: SessionCapabilities
    let remoteEndPoint: String
//    let playableMediaTypes: [],
    let id: String
    let userId: String
    let userName: String
    let client: String
    let lastActivityDate: String
    let lastPlaybackCheckIn: String
    let deviceName: String
    let deviceId: String
    let applicationVersion: String
    let isActive: Bool
    let supportsMediaControl: Bool
    let supportsRemoteControl: Bool
//    let nowPlayingQueue: [],
//    let nowPlayingQueueFullItems: [],
    let hasCustomDeviceName: Bool
    let serverId: String
//    let supportedCommands: []
}

struct SessionPlayState: Codable {
    let canSeek: Bool
    let isPaused: Bool
    let isMuted: Bool
    let repeatMode: String
}

struct SessionCapabilities: Codable {
//    let playableMediaTypes: [],
//    let supportedCommands: [],
    let supportsMediaControl: Bool
    let supportsContentUploading: Bool
    let supportsPersistentIdentifier: Bool
    let supportsSync: Bool
}
