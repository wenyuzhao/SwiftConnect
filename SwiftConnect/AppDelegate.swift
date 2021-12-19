//
//  AppDelegate.swift
//  SwiftConnect
//
//  Created by Wenyu Zhao on 8/12/2021.
//

import Cocoa
import SwiftUI
import SwiftShell



class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static var shared: AppDelegate!;
    
    var pinPopover = false
    
    private lazy var icon: NSImage = {
        let image = NSImage(named: "AppIcon")!
        image.size = NSSize(width: 18, height: 18)
        return image
    }()
    private lazy var popover: NSPopover = {
        let popover = NSPopover()
        let contentView = ContentView()
        popover.contentSize = NSSize(width: 200, height: 200)
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.behavior = .transient
        popover.delegate = self
        return popover
    }()
    private lazy var statusItem: NSStatusItem = {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = icon
        statusItem.button?.image?.isTemplate = true
        statusItem.button!.action = #selector(togglePopover(sender:))
        statusItem.button!.sendAction(on: [.leftMouseUp, .rightMouseUp])
        return statusItem
    }()
    private lazy var contextMenu: ContextMenu = ContextMenu(statusBarItem: statusItem)
    
    func vpnConnectionDidChange(connected: Bool) {
        statusItem.button?.image = icon
        statusItem.button?.image?.isTemplate = !connected
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        Self.shared = self;
        // Hide app window
        NSApplication.shared.windows.first?.close()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)
        // Hide app window
        if let window = NSApplication.shared.windows.first {
            window.close()
        }
        if !testPrivilege() {
            relaunch()
        }
        // Initialize statusItem
        statusItem.button!.target = self
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        VPNController.killOpenConnect();
    }
    
    func popoverWillShow(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        return !pinPopover
    }
    
    @objc func togglePopover(sender: AnyObject) {
        if NSApp.currentEvent!.type ==  NSEvent.EventType.leftMouseUp {
            if (popover.isShown) {
                closePopover()
            } else {
                openPopover()
            }
        } else {
            contextMenu.show()
        }
    }
    
    func openPopover() {
        popover.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: NSRectEdge.maxY)
    }
    
    func closePopover() {
        popover.performClose(self)
    }
    
    func testPrivilege() -> Bool {
        return getuid() == 0;
    }
    
    func relaunch() {
        let bin = Bundle.main.executablePath!;
        print("Relaunch: sudo \(bin)");
        let _ = try! runAndPrint(bash: """
            osascript -e "do shell script \\"sudo '\(bin)' &\\" with prompt \\"Start OpenConnect on privileged mode\\" with administrator privileges"&
        """);
        NSApp.terminate(nil)
    }
}


class ContextMenu: NSObject, NSMenuDelegate {
    let statusBarItem: NSStatusItem

    func buildContextMenu() -> NSMenu {
        let menu = NSMenu(title: "Status Bar Menu")
        menu.delegate = self
        // Title
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let title = menu.addItem(
            withTitle: "SwiftConnect v\(appVersion)",
            action: #selector(self.openProjectURL(_:)),
            keyEquivalent: ""
        )
        title.image = NSImage(named: "AppIcon")!
        title.image?.isTemplate = true
        title.target = self
        // Separator
        menu.addItem(NSMenuItem.separator())
        // Quit button
        let qitem = menu.addItem(
            withTitle: "⎋ Quit",
            action: #selector(self.quit(_:)),
            keyEquivalent: "q"
        )
        qitem.target = self
        return menu
    }
    
    init(statusBarItem: NSStatusItem) {
        self.statusBarItem = statusBarItem
        super.init()
    }
    
    func show() {
        statusBarItem.menu = buildContextMenu()
        statusBarItem.button?.performClick(nil)
    }
    
    @objc func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    @objc func menuDidClose(_ menu: NSMenu) {
        statusBarItem.menu = nil
    }
    
    @objc func openProjectURL(_ menu: NSMenuItem) {
        NSWorkspace.shared.open(URL(string: "https://github.com/wenyuzhao/SwiftConnect")!)
    }
}

