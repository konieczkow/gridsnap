import Cocoa
import ServiceManagement

let presetMenu = NSMenu()
func rebuildPresetMenu() {
    presetMenu.removeAllItems()
    for (i, p) in presets.enumerated() {
        let item = presetMenu.addItem(withTitle: p.name, action: #selector(MenuActions.applyPresetItem), keyEquivalent: String(p.keyLabel.last ?? " ").lowercased())
        item.keyEquivalentModifierMask = modifierFlags(p.keyMods); item.tag = i; item.target = actions
    }
    if !presets.isEmpty { presetMenu.addItem(.separator()) }
    presetMenu.addItem(withTitle: "Shift-release on the grid saves a preset", action: nil, keyEquivalent: "")
}

let statusItem: NSStatusItem = {
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    status.button?.image = NSImage(systemSymbolName: "square.grid.3x2", accessibilityDescription: "GridSnap")
    let menu = NSMenu()
    let undoItem = menu.addItem(withTitle: "Undo Last Snap", action: #selector(MenuActions.undo), keyEquivalent: "z")
    undoItem.keyEquivalentModifierMask = [.control, .option]; undoItem.target = actions
    menu.addItem(withTitle: "Presets", action: nil, keyEquivalent: "").submenu = presetMenu
    rebuildPresetMenu()
    menu.addItem(withTitle: "Settings…", action: #selector(MenuActions.showPrefs), keyEquivalent: ",").target = actions
    let login = menu.addItem(withTitle: "Launch at Login", action: #selector(MenuActions.toggleLogin), keyEquivalent: "")
    login.target = actions
    login.state = SMAppService.mainApp.status == .enabled ? .on : .off
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit GridSnap", action: #selector(NSApplication.terminate), keyEquivalent: "q")
    status.menu = menu
    return status
}()
