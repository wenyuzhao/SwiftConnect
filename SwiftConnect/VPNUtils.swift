//
//  VPNUtils.swift
//  SwiftConnect
//
//  Created by Wenyu Zhao on 8/12/2021.
//

import Foundation
import SwiftShell
import SwiftUI
import Security



enum VPNState {
    case stopped, processing, launched
    
    var description : String {
      switch self {
      case .stopped: return "stopped"
      case .processing: return "launching"
      case .launched: return "launched"
      }
    }
}

enum VPNProtocol: String, Equatable, CaseIterable {
    case globalProtect = "gp"
    
    var id: String {
        return self.rawValue
    }
    
    var name: String {
        switch self {
        case .globalProtect: return "GlobalProtect"
        }
    }
}

class VPNController: ObservableObject {
    @Published public var state: VPNState = .stopped
    @Published public var proto: VPNProtocol = .globalProtect
    
    private var currentLogURL: URL?;
    
    func start(credentials: Credentials, save: Bool) {
        if save {
            credentials.save()
        }
        AppDelegate.shared.pinPopover = true
        Self.killOpenConnect();
        start(portal: credentials.portal, username: credentials.username, password: credentials.password) { succ in
            AppDelegate.shared.pinPopover = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                AppDelegate.shared.closePopover()
            }
        }
    }
    
    private func start(portal: String, username: String, password: String, _ onLaunch: @escaping (_ succ: Bool) -> Void) {
        state = .processing
        AppDelegate.shared.vpnConnectionDidChange(connected: false)
        // Prepare commands
        print("[openconnect] start")
        // stdin to input password
        let stdinPath = URL(fileURLWithPath: "\(NSTemporaryDirectory())/\(NSUUID().uuidString)");
        try! password.write(to: stdinPath, atomically: true, encoding: .utf8)
        let stdin = try! FileHandle(forReadingFrom: stdinPath)
        // stdout for logging
        let stdoutPath = URL(fileURLWithPath: "\(NSTemporaryDirectory())/\(NSUUID().uuidString)");
        try! "".write(to: stdoutPath, atomically: true, encoding: .utf8)
        let stdout = try! FileHandle(forReadingFrom: stdoutPath)
        currentLogURL = stdoutPath
        print("[openconnect] log: \(stdoutPath.path)")
        // Run
        var context = CustomContext(main)
        context.stdin = FileHandleStream(stdin, encoding: .utf8)
        let shellCommand = "/usr/local/bin/openconnect --protocol=\(proto.id) \(portal) -u \(username) --passwd-on-stdin"
        let command = context.runAsync(bash: "\(shellCommand) &> \(stdoutPath.path)")
        print("[openconnect] cmd: \(shellCommand)")
        // Launch callback
        var launched = false;
        watchLaunch(file: stdout) {
            print("[openconnect] launched")
            launched = true;
            onLaunch(true)
        }
        // Completion callback
        command.onCompletion { _ in
            if self.state != .stopped {
                DispatchQueue.main.async {
                    if self.state != .stopped {
                        self.state = .stopped
                        AppDelegate.shared.vpnConnectionDidChange(connected: false)
                    }
                }
            }
            if !launched {
                onLaunch(false)
            }
            try? stdin.close()
            try? stdout.close()
            print("[openconnect] completed")
        }
    }
    
    func watchLaunch(file: FileHandle, callback: @escaping () -> Void) {
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: file.fileDescriptor,
            eventMask: .extend,
            queue: DispatchQueue.main
        )
        source.setEventHandler {
            guard source.data.contains(.extend) else { return }
            if self.state == .processing {
                self.state = .launched
                AppDelegate.shared.vpnConnectionDidChange(connected: true)
                callback()
            }
        }
        source.setCancelHandler {
            try? file.close()
        }
        file.seekToEndOfFile()
        source.resume()
    }
    
    func kill() {
        state = .processing
        Self.killOpenConnect();
        state = .stopped
        AppDelegate.shared.vpnConnectionDidChange(connected: false)
    }
    
    static func killOpenConnect() {
        print("[openconnect] kill")
        run("pkill", "openconnect");
    }
    
    func openLogFile() {
        if let url = currentLogURL {
            NSWorkspace.shared.open(url)
        }
    }
}



class Credentials: ObservableObject {
    @Published public var portal: String
    @Published public var username: String
    @Published public var password: String
    
    init() {
        if let data = ContentView.inPreview ? nil : KeychainService.shared.load() {
            username = data.username
            password = data.password
            portal = data.portal
        } else {
            portal = "student-access.anu.edu.au"
            username = ""
            password = ""
        }
    }
    
    func save() {
        let _ = KeychainService.shared.insertOrUpdate(credentials: CredentialsData(portal: portal, username: username, password: password))
    }
}

struct CredentialsData {
    let portal: String
    let username: String
    let password: String
}

class KeychainService: NSObject {
    public static let shared = KeychainService();
    
    private static let server = "swift-connect.wenyu.me"
    
    func insertOrUpdate(credentials: CredentialsData) -> Bool {
        let username = credentials.username
        let password = credentials.password.data(using: String.Encoding.utf8)!
        let portal = credentials.portal
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: Self.server,
        ]
        let attributes: [String: Any] = [
            kSecAttrAccount as String: username,
            kSecValueData as String: password,
            kSecAttrDescription as String: portal,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let query: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrAccount as String: username,
                kSecAttrServer as String: Self.server,
                kSecValueData as String: password,
                kSecAttrDescription as String: portal,
            ]
            let status = SecItemAdd(query as CFDictionary, nil)
            return status == errSecSuccess
        } else {
            return status == errSecSuccess
        }
    }
    
    func load() -> CredentialsData? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: Self.server,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else { return nil }
        
        guard let existingItem = item as? [String : Any],
            let passwordData = existingItem[kSecValueData as String] as? Data,
            let password = String(data: passwordData, encoding: String.Encoding.utf8),
            let username = existingItem[kSecAttrAccount as String] as? String,
            let portal = existingItem[kSecAttrDescription as String] as? String
        else {
            return nil
        }
        
        return CredentialsData(portal: portal, username: username, password: password)
    }
}
