//
//  LoginUtils.swift
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
    
    let logPath: String;
    let file: FileHandle
    let source: DispatchSourceFileSystemObject
    
    func start(username: String, password: String) {
        print("[openconnect start]")
        state = .processing
        print("[output \(logPath)]")
        let shellCommand = "sudo /usr/local/bin/openconnect --protocol=\(proto.id) student-access.anu.edu.au -u \(username) --passwd-on-stdin --reconnect-timeout 100000";
        let shellCommandWithIO = "\(shellCommand) <<< \(password) &> \(logPath)";
        print("[cmd: \(shellCommand)]")
        let command = runAsync("osascript", "-e", """
            do shell script \"\(shellCommandWithIO)\" with prompt \"Start OpenConnect\" with administrator privileges
        """);
        command.onCompletion { _ in
            if self.state != .stopped {
                DispatchQueue.main.async {
                    if self.state != .stopped {
                        self.state = .stopped
                    }
                }
            
            }
            print("[openconnect completed]")
        }
    }
    
    func kill() {
        state = .processing
        print("[kill openconnect]")
        run("pkill", "-9", "openconnect");
        state = .stopped
    }
    
    init() {
        logPath = "\(NSTemporaryDirectory())/\(NSUUID().uuidString)";
        let url = URL(fileURLWithPath: logPath)
        try! "".write(to: url, atomically: true, encoding: .utf8)
        file = try! FileHandle(forReadingFrom: url)
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: file.fileDescriptor,
            eventMask: .extend,
            queue: DispatchQueue.main
        )
        source.setEventHandler {
            self.handleLogFileEvent(event: self.source.data)
        }
        source.setCancelHandler {
            try? self.file.close()
        }
        file.seekToEndOfFile()
        source.resume()
    }
    
    deinit {
        source.cancel()
    }

    func handleLogFileEvent(event: DispatchSource.FileSystemEvent) {
        guard event.contains(.extend) else {
            return
        }
        if self.state == .processing {
            self.state = .launched
        }
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
