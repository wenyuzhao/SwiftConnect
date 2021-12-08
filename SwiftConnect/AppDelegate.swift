//
//  AppDelegate.swift
//  SwiftConnect
//
//  Created by Wenyu Zhao on 8/12/2021.
//

import Cocoa
import SwiftUI



class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static var pinPopover = false
    static var handleConnectionChange: (_ connected: Bool) -> Void = { _ in };
    private var popover = NSPopover()
    private var statusItem: NSStatusItem!

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Hide app window
        NSApplication.shared.windows.first?.close()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide app window
        if let window = NSApplication.shared.windows.first {
            window.close()
        }
        // Initialize popover
        let contentView = ContentView()
        popover.contentSize = NSSize(width: 200, height: 200)
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.behavior = .transient
        popover.delegate = self
        // Initialize status bar button
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🔘"
        statusItem.button!.action = #selector(togglePopover(sender:))
        statusItem.button!.target = self
        Self.handleConnectionChange = { connected in
            self.statusItem.button?.title = connected ? "🌐" : "🔘"
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func popoverWillShow(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        return !Self.pinPopover
    }
    
    @objc func togglePopover(sender: AnyObject) {
        if (popover.isShown) {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: NSRectEdge.maxY)
        }
    }
}
