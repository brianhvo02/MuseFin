//
//  CarPlaySceneDelegate.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/13/23.
//

import CarPlay
import SwiftData
import Combine

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    
    var cancellable : AnyCancellable?
    
    var shuffle: Bool = false
    var shuffleButton: CPNowPlayingImageButton?
    
    var repeatMode: RepeatMode = .off
    var repeatButton: CPNowPlayingImageButton?
    
    func updateShuffle() {
        guard let image = UIImage(systemName: "shuffle") else {
            return
        }
        
        shuffle = AudioManager.shared.shuffle
        let button = CPNowPlayingImageButton(image: image) { button in
            AudioManager.shared.toggleShuffle()
        }
        button.isSelected = shuffle
        shuffleButton = button
    }
    
    func updateRepeat() {
        repeatMode = AudioManager.shared.repeatMode
        guard let image = UIImage(systemName: repeatMode == .track ? "repeat.1" : "repeat") else {
            return
        }
        
        let button = CPNowPlayingImageButton(image: image) { button in
            AudioManager.shared.toggleRepeat()
        }
        button.isSelected = repeatMode != .off
        repeatButton = button
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        
        cancellable = AudioManager.shared
            .objectWillChange
            .receive(on: RunLoop.main)
            .sink { [unowned self] _ in
                if shuffle != AudioManager.shared.shuffle {
                    updateShuffle()
                }
                
                if repeatMode != AudioManager.shared.repeatMode {
                    updateRepeat()
                }
                
                let buttons = [shuffleButton, repeatButton].compactMap { $0 }
                CPNowPlayingTemplate.shared.updateNowPlayingButtons(buttons)
            }
        
        updateShuffle()
        updateRepeat()
        
        let buttons = [shuffleButton, repeatButton].compactMap { $0 }
        CPNowPlayingTemplate.shared.updateNowPlayingButtons(buttons)
        
        Task {
            var templates = [CPListTemplate]()
            
            if
                let ctx = try? ModelContainer(for: UserInfo.self, OfflineTrack.self).mainContext,
                let users = try? ctx.fetch(FetchDescriptor<UserInfo>()),
                users.indices.contains(0)
            {
                if JellyfinAPI.isConnectedToNetwork() {
                    do {
                        let _ = try await JellyfinAPI.shared.tokenLogin(user: users[0])
                        
                        let playlist = await List.getPlaylists(interfaceController: interfaceController)
                        templates.append(playlist.template)
                        
                        let albumList = await List.getAlbums(interfaceController: interfaceController)
                        templates.append(albumList.template)
                    } catch {
                        print(error.localizedDescription)
                        return
                    }
                } else {
                    JellyfinAPI.shared.serverUrl = URL(string: users[0].serverUrl)
                    JellyfinAPI.shared.token = users[0].token
                    JellyfinAPI.shared.userId = users[0].userId
                    
                    let playlist = List.getPlaylists(ctx: ctx, interfaceController: interfaceController)
                    templates.append(playlist.template)
                    
                    let albumList = List.getAlbums(ctx: ctx, interfaceController: interfaceController)
                    templates.append(albumList.template)
                }
                
                try await interfaceController.setRootTemplate(CPTabBarTemplate(templates: templates), animated: true)
            }
        }
    }
    
    private func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }
}
