// gridsnap — hotkey, drag a grid, focused window snaps to it. Build: ./build.sh
// Sources/: Defaults (stored settings), AX (window plumbing), Grid (overlay), Presets, Hotkeys, ShortcutButton, SettingsWindow, Menu
import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
_ = statusItem   // globals outside main.swift are lazy; touching it builds the menu bar item

func startApp() {
    installHotKeyHandler()
    // clicks on other apps never reach the panel; a global monitor sees them and dismisses
    NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in if panel.isVisible { hideGrid() } }
}

if AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) {
    startApp()
} else {
    let grant = NSMenuItem(title: "Grant Accessibility…", action: #selector(MenuActions.openAccessibility), keyEquivalent: "")
    grant.target = actions
    statusItem.menu?.insertItem(grant, at: 0); statusItem.menu?.insertItem(.separator(), at: 1)
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
        guard AXIsProcessTrusted() else { return }
        t.invalidate(); statusItem.menu?.removeItem(at: 1); statusItem.menu?.removeItem(at: 0); startApp()
    }
}

app.run()
