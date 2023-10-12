//
//  MusicPlayerView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/7/23.
//

import SwiftUI

struct Blur: View {
    @ObservedObject var manager: AudioManager
    
    var body: some View {
        if
            let track = manager.currentTrack,
            let blurHash = track.blurHash,
            let image = UIImage(blurHash: blurHash, size: CGSize(width: 32, height: 32))
        {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .brightness(-0.3)
        } else {
            Color.secondaryBackground
        }
    }
}

func convertSeconds(_ totalSeconds: Double) -> String {
    let minutes = Int(totalSeconds / 60)
    let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60.0))
    
    return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
}


struct MusicPlayerView: View {
    @Binding var showNowPlaying: Bool
    @Binding var path: NavigationPath
    @ObservedObject var manager: AudioManager
    
    var body: some View {
        if let metadata = manager.currentTrack {
            VStack(spacing: 16) {
                HStack {
                    Button {
                        showNowPlaying.toggle()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    
                    Spacer()
                    
                    Text(metadata.listName)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .padding(.horizontal)
                        .frame(alignment: .bottom)
                    
                    Spacer()
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
                
                Spacer()
                
                ListImage(metadata: metadata)
                    .frame(maxWidth: .infinity)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(metadata.name)
                        .font(.custom("Quicksand", size: 24))
                        .fontWeight(.bold)
                        .lineLimit(1)
                        
                    Text(metadata.artist)
                        .font(.custom("Quicksand", size: 16))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 2) {
                    Slider(
                        value: $manager.elapsed,
                        in: 0...(manager.currentTrack?.duration ?? 0.0),
                        onEditingChanged: { editing in
                            manager.isEditing = editing
                            if !editing {
                                manager.seek(manager.elapsed)
                            }
                        }
                    )
                    HStack {
                        Text(convertSeconds(manager.elapsed))
                        Spacer()
                        Text("-" + convertSeconds((manager.currentTrack?.duration ?? 0.0) - manager.elapsed))
                    }
                }
                
                HStack {
                    Button {
                        manager.toggleShuffle()
                    } label: {
                        Image(systemName: "shuffle")
                            .foregroundStyle(manager.shuffle ? Color.accent : Color.primaryText)
                    }
                    
                    Spacer()
                    
                    Button {
                        manager.prev()
                    } label: {
                        Image(systemName: "backward.end.fill")
                    }
                    
                    Spacer()
                    
                    Button {
                        if manager.isPlaying {
                            manager.pause()
                        } else {
                            manager.play()
                        }
                    } label: {
                        Image(systemName: manager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    }
                    .font(.system(size: 56))
                    
                    Spacer()
                    
                    Button {
                        manager.next()
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                    
                    Spacer()
                    
                    Button {
                        manager.toggleRepeat()
                    } label: {
                        Image(systemName: manager.repeatMode == RepeatMode.track ? "repeat.1" : "repeat")
                            .foregroundStyle(manager.repeatMode == RepeatMode.off ? Color.primaryText : Color.accent)
                    }
                }
                .font(.system(size: 28))
                
                Spacer()
            }
            .padding(.all)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Blur(manager: manager)
                    .ignoresSafeArea(.all)
            )
        }
    }
}
