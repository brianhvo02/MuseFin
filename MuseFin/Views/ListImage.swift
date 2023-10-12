//
//  ListImage.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/11/23.
//

import SwiftUI
import NukeUI

struct ListImage: View {
    let metadata: TrackMetadata?
    let list: MiniList?
    let width: CGFloat?
    let height: CGFloat?
    
    init(list: MiniList, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.metadata = nil
        self.list = list
        self.width = width
        self.height = height
    }
    
    init(metadata: TrackMetadata, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.list = nil
        self.metadata = metadata
        self.width = width
        self.height = height
    }
    
    var body: some View {
        Group {
            if let metadata = metadata, let artwork = metadata.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if let list = list {
                if JellyfinAPI.isConnectedToNetwork() {
                    LazyImage(
                        url: JellyfinAPI.shared.getItemImageUrl(itemId: list.id)
                    ) { image in
                        if let image = image.image {
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                        } else {
                            Image("LogoDark")
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    
                } else if let artwork = list.artwork, let image = UIImage(data: artwork) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    Image("LogoDark")
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        
    }
}
