//
//  MuseFinApp.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/2/23.
//

import SwiftUI

@main
struct MuseFinApp: App {
    @StateObject private var dataController = DataController()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .foregroundStyle(.white)
                .font(.custom("Quicksand", size: 16))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("BackgroundColor"))
        }
    }
}
