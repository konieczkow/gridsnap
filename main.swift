// gridsnap — hotkey, drag a grid, focused window snaps to it. Build: ./build.sh
// Files: Defaults (stored settings), AX (window plumbing), Grid (overlay), Presets, Hotkeys, ShortcutButton, SettingsWindow, Menu
import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

guard AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) else {
    print("Grant Accessibility permission in System Settings, then relaunch."); exit(1)
}

installHotKeyHandler()
_ = statusItem   // globals outside main.swift are lazy; touching it builds the menu bar item
// clicks on other apps never reach the panel; a global monitor sees them and dismisses
NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in if panel.isVisible { hideGrid() } }

app.run()
