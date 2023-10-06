//
//  LoadingView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/2/23.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Image("LogoDark")
                .resizable()
                .frame(width: 75, height: 75)
            Text("MuseFin")
                .font(.custom("Quicksand", size: 24))
            VStack(alignment: .center) {
                Text("Your Jellyfin music,")
                Text("straight from your server.")
            }
        }
        .fontWeight(.bold)
    }
}
