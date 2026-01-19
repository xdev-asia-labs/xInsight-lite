import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hiển thị app trong Dock và activate window
        NSApp.setActivationPolicy(.regular)
        
        // Focus vào app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.activate(ignoringOtherApps: true)
        }
        
        // Listen for OpenDashboard notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenDashboard),
            name: NSNotification.Name("OpenDashboard"),
            object: nil
        )
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Không terminate khi đóng window - app vẫn chạy ở menu bar
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Khi click vào Dock icon, mở Dashboard
        if !flag {
            openDashboardWindow()
        }
        return true
    }
    
    @objc func handleOpenDashboard(_ notification: Notification) {
        openDashboardWindow()
    }
    
    func openDashboardWindow() {
        print("[AppDelegate] 📊 Opening Dashboard...")
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Find and show any existing window
        for window in NSApp.windows {
            let title = window.title
            // Skip status bar popovers and other system windows
            if title.isEmpty || title.starts(with: "Item-") {
                continue
            }
            
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            print("[AppDelegate] ✅ Activated window: \(title)")
            return
        }
        
        // If no content window found, try to deminiaturize any window
        if let firstWindow = NSApp.windows.first(where: { !$0.title.isEmpty && !$0.title.starts(with: "Item-") }) {
            firstWindow.deminiaturize(nil)
            firstWindow.makeKeyAndOrderFront(nil)
            print("[AppDelegate] ✅ Deminiaturized window: \(firstWindow.title)")
            return
        }
        
        print("[AppDelegate] ⚠️ No dashboard window available. Please restart the app to see Dashboard.")
    }
}
