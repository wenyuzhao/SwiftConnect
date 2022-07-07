//
//  ContentView.swift
//  SwiftConnect
//
//  Created by Wenyu Zhao on 8/12/2021.
//

import SwiftUI

let windowSize = CGSize(width: 200, height: 230)
let windowInsets = EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30)

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
        ZStack {
            VStack {
                Image("Connected")
                    .resizable()
                    .scaledToFit()
                Text("🌐 VPN Connected!")
                Spacer().frame(height: 25)
                Button(action: { vpn.kill() }) {
                    Text("Disconnect")
                }.keyboardShortcut(.defaultAction)
        }
        Button(action: { vpn.openLogFile() }) {
            Text("logs").underline()
                .foregroundColor(Color.gray)
                .fixedSize(horizontal: false, vertical: true)
        }.buttonStyle(PlainButtonStyle())
                .position(x: 155, y: 190)
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
            }
            TextField("Portal", text: $credentials.portal)
            TextField("Username", text: $credentials.username)
            SecureField("Password", text: $credentials.password).onSubmit {
                vpn.start(credentials: credentials, save: saveToKeychain)
            }
            Toggle(isOn: $saveToKeychain) {
                Text("Save to Keychain")
            }.toggleStyle(CheckboxToggleStyle())
            Spacer().frame(height: 25)
            Button(action: {
                vpn.start(credentials: credentials, save: saveToKeychain)
            }) {
                Text("Connect")
            }.keyboardShortcut(.defaultAction)
        }
    }
}


struct ContentView: View {
    @StateObject var vpn = VPNController()
    @StateObject var credentials: Credentials
    let forceState: VPNState?;
    
    init(forceState: VPNState? = nil) {
        self.forceState = forceState;
        _credentials = StateObject(wrappedValue: Credentials())
    }
    
    var body: some View {
        VStack {
            switch forceState ?? vpn.state {
            case .stopped: VPNLoginScreen()
            case .processing: ProgressView()
            case .launched: VPNLaunchedScreen()
            }
        }
        .padding(windowInsets)
        .frame(width: windowSize.width, height: windowSize.height).background(VisualEffect()).environmentObject(vpn).environmentObject(credentials)
    }
    
    static let inPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1";
}


struct VPNLoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(forceState: VPNState.stopped)
    }
}

struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(forceState: VPNState.processing)
    }
}

struct VPNLaunchedScreen_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(forceState: VPNState.launched)
    }
}
