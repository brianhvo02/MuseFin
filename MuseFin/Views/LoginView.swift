//
//  LoginView.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/2/23.
//

import SwiftUI

struct LoginView: View {
    @Binding var loggedIn: Bool?
    @State private var serverAddr: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var error: String = ""
    @Environment(\.managedObjectContext) var ctx
    @FetchRequest(sortDescriptors: []) var users: FetchedResults<UserInfo>
    
    func submitLogin() async {
        guard let serverUrl = URL(string: serverAddr) else {
            return
        }
        
        error = ""
        do {
            let payload = try await JellyfinAPI.shared.login(
                serverUrl: serverUrl,
                username: username,
                password: password
            )
            
            let user = UserInfo(context: ctx)
            user.id = payload.user.id
            user.token = payload.accessToken
            user.serverUrl = serverUrl.absoluteString
            try ctx.save()
            loggedIn = true
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
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
            
            VStack(alignment: .center, spacing: 24) {
                Text(error)
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading) {
                    Text("Server address")
                    TextField("", text: $serverAddr)
                        .textInputAutocapitalization(.never)
                        .background(Color.gray)
                }
                
                VStack(alignment: .leading) {
                    Text("Username")
                    TextField("", text: $username)
                        .textInputAutocapitalization(.never)
                        .background(Color.gray)
                }
                
                VStack(alignment: .leading) {
                    Text("Password")
                    SecureField("", text: $password)
                        .textInputAutocapitalization(.never)
                        .background(Color.gray)
                }
                
                Button("Login") {
                    Task {
                        await submitLogin()
                    }
                }
            }
            .fontWeight(.bold)
        }
        .padding(.all)
    }
}
