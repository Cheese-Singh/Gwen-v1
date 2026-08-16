//
//  SuperGwenApp.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let backendLauncher = BackendLauncher()

    func applicationWillTerminate(_ notification: Notification) {
        backendLauncher.shutdown()
    }
}

@main
struct SuperGwenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(backendLauncher: appDelegate.backendLauncher)
        }
    }
}
