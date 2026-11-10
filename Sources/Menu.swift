import Cocoa
import ServiceManagement

let presetMenu = NSMenu()
let undoItem = NSMenuItem(title: "Undo Last Snap", action: #selector(MenuActions.undo), keyEquivalent: "")
func refreshUndoItem() {
    undoItem.keyEquivalent = String(undoCombo.label.last ?? " ").lowercased(); undoItem.keyEquivalentModifierMask = modifierFlags(undoCombo.mods)
}
func rebuildPresetMenu() {
    presetMenu.removeAllItems()
    for (i, p) in presets.enumerated() {
        let item = presetMenu.addItem(withTitle: p.name, action: #selector(MenuActions.applyPresetItem),
                                      keyEquivalent: p.combo?.label.last.map { String($0).lowercased() } ?? "")
        item.keyEquivalentModifierMask = modifierFlags(p.combo?.mods ?? 0); item.tag = i; item.target = actions
    }
    if !presets.isEmpty { presetMenu.addItem(.separator()) }
    if !presets.isEmpty { presetMenu.addItem(withTitle: "On the grid, 1 to 9 apply these in order", action: nil, keyEquivalent: "") }
    presetMenu.addItem(withTitle: "Shift-release on the grid saves a preset", action: nil, keyEquivalent: "")
}

let statusItem: NSStatusItem = {
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    status.button?.image = NSImage(systemSymbolName: "square.grid.3x2", accessibilityDescription: "GridSnap")
    let menu = NSMenu()
    undoItem.target = actions; refreshUndoItem(); menu.addItem(undoItem)
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
