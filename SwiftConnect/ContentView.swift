//
//  ContentView.swift
//  SwiftConnect
//
//  Created by Wenyu Zhao on 8/12/2021.
//

import SwiftUI

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Self.Context) -> NSView {
        let visualEffect = NSVisualEffectView();
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .popover
        return visualEffect
    }
    
    func updateNSView(_ nsView: NSView, context: Context) { }
}

struct VPNLaunchedScreen: View {
    @EnvironmentObject var vpn: VPNController
    
    var body: some View {
        VStack {
            Image( "Connected")
                .resizable()
                .scaledToFit()
            Text("🌐 VPN Connected!")
            Spacer().frame(height: 20)
            Button(action: { vpn.kill() }) {
                Text("Disconnect")
            }.keyboardShortcut(.defaultAction)
        }
    }
}

struct VPNLoginScreen: View {
    @EnvironmentObject var vpn: VPNController
    @EnvironmentObject var credentials: Credentials
    @State private var saveToKeychain = true
    
    var body: some View {
        VStack {
            Picker(selection: $vpn.proto, label: EmptyView()) {
                ForEach(VPNProtocol.allCases, id: \.self) {
                    Text($0.name)
                }
            }.frame(width: 120)
            TextField("Username", text: $credentials.username).frame(width: 120)
            SecureField("Password", text: $credentials.password).frame(width: 120)
            Toggle(isOn: $saveToKeychain) {
                Text("Save to Keychain")
            }.toggleStyle(CheckboxToggleStyle())
            Spacer().frame(height: 25)
            Button(action: {
                if saveToKeychain {
                    credentials.save()
                }
                vpn.start(username: credentials.username, password: credentials.password)
            
            }) {
                Text("Connect")
            }.keyboardShortcut(.defaultAction)
        }
    }
}


struct ContentView: View {
    @StateObject var vpn = VPNController()
    @StateObject var credentials = Credentials()
    
    var body: some View {
        VStack {
            switch vpn.state {
            case .stopped: VPNLoginScreen()
            case .processing: ProgressView()
            case .launched: VPNLaunchedScreen()
            }
        }
        .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
        .frame(width: 200, height: 200).background(VisualEffect()).environmentObject(vpn).environmentObject(credentials)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
