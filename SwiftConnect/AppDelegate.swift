//
//  AppDelegate.swift
//  SwiftConnect
//
//  Created by Wenyu Zhao on 8/12/2021.
//

import Cocoa
import SwiftUI



class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static var shared: AppDelegate!;
    static var pinPopover = false
    static var handleConnectionChange: (_ connected: Bool) -> Void = { _ in };
    
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
        statusItem.button?.title = "🔘"
        statusItem.button!.action = #selector(togglePopover(sender:))
        statusItem.button!.sendAction(on: [.leftMouseUp, .rightMouseUp])
        Self.handleConnectionChange = { connected in
            self.statusItem.button?.title = connected ? "🌐" : "🔘"
        }
        return statusItem
    }()
    private lazy var contextMenu: ContextMenu = ContextMenu(statusBarItem: statusItem)

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
        return !Self.pinPopover
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
}


class ContextMenu: NSObject, NSMenuDelegate {
    let statusBarItem: NSStatusItem

    func buildContextMenu() -> NSMenu {
        let menu = NSMenu(title: "Status Bar Menu")
        menu.delegate = self
        menu.addItem(
            withTitle: "🌐 SwiftConnect",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(NSMenuItem.separator())
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
        statusBarItem.menu = nil // remove menu so button works as before
    }
}

