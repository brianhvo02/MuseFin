//
//  NavScrollView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/7/23.
//

import SwiftUI

struct NavScrollView<Content: View>: View {
    @ObservedObject var manager: AudioManager
    @ViewBuilder let content: Content
    
    var body: some View {
        ZStack {
            Color.background.edgesIgnoringSafeArea(.all)
            ScrollView {
                if !JellyfinAPI.isConnectedToNetwork() {
                    Text("You are in offline mode")
                        .padding(.all)
                        .frame(maxWidth: .infinity)
                        .background(Color.secondaryBackground)
                        .padding(.top)
                }
                
                content
                    .padding(.horizontal)
                    .padding(.top)
                
                if let _ = manager.currentTrack {
                    Spacer()
                        .frame(height: 100)
                }
            }
        }
    }
}
