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

//let logPath = "\(NSTemporaryDirectory())/\(NSUUID().uuidString)";

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
    
//    let logPath = "\(NSTemporaryDirectory())/\(NSUUID().uuidString)";
//    lazy var logPathUrl = URL(fileURLWithPath: logPath);
    
    func start(username: String, password: String, _ onLaunch: @escaping (_ succ: Bool) -> Void) {
        state = .processing
        AppDelegate.handleConnectionChange(false)
        // Prepare commands
        print("[openconnect start]")
        let logPath = "\(NSTemporaryDirectory())/\(NSUUID().uuidString)";
        let logPathUrl = URL(fileURLWithPath: logPath);
        try! "".write(to: logPathUrl, atomically: true, encoding: .utf8)
        print("[output \(logPath)]")
        let shellCommand = "sudo /usr/local/bin/openconnect --protocol=\(proto.id) student-access.anu.edu.au -u \(username) --passwd-on-stdin";
        let shellCommandWithIO = "\(shellCommand) <<< \(password) &> \(logPath)";
        print("[cmd: \(shellCommand)]")
        // Launch
        var launched = false;
        let file = try! FileHandle(forReadingFrom: logPathUrl)
        watchLaunch(file: file) {
            launched = true;
            onLaunch(true)
        }
        let command = runAsync("osascript", "-e", """
            do shell script \"\(shellCommandWithIO)\" with prompt \"Start OpenConnect\" with administrator privileges
        """);
        // Completion callback
        command.onCompletion { _ in
            if self.state != .stopped {
                DispatchQueue.main.async {
                    if self.state != .stopped {
                        self.state = .stopped
                        AppDelegate.handleConnectionChange(false)
                    }
                }
            }
            if !launched {
                onLaunch(false)
            }
            try? file.close()
            print("[openconnect completed]")
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
                AppDelegate.handleConnectionChange(true)
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
        print("[kill openconnect]")
        run("pkill", "-9", "openconnect");
        state = .stopped
        AppDelegate.handleConnectionChange(false)
    }
}



class Credentials: ObservableObject {
    @Published public var username: String
    @Published public var password: String
    
    init() {
        if let data = KeychainService.shared.load() {
            username = data.username
            password = data.password
        } else {
            username = ""
            password = ""
        }
    }
    
    func save() {
        let _ = KeychainService.shared.insertOrUpdate(credentials: CredentialsData(username: username, password: password))
    }
}

struct CredentialsData {
    let username: String
    let password: String
}

class KeychainService: NSObject {
    public static let shared = KeychainService();
    
    private static let server = "swift-connect.wenyu.me"
    
    func insertOrUpdate(credentials: CredentialsData) -> Bool {
        let username = credentials.username
        let password = credentials.password.data(using: String.Encoding.utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: Self.server,
        ]
        let attributes: [String: Any] = [
            kSecAttrAccount as String: username,
            kSecValueData as String: password,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let query: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrAccount as String: username,
                kSecAttrServer as String: Self.server,
                kSecValueData as String: password
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
            let username = existingItem[kSecAttrAccount as String] as? String
        else {
            return nil
        }
        
        return CredentialsData(username: username, password: password)
    }
}
