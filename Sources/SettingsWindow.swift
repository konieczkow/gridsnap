import Cocoa
import ServiceManagement

final class MenuActions: NSObject {
    @objc func undo() { undoSnap() }
    @objc func applyPresetItem(_ item: NSMenuItem) { if item.tag < presets.count { applyPreset(presets[item.tag]) } }
    @objc func pickTarget(_ b: NSButton) { defaults.set(b.tag == 1, forKey: "underCursor") }
    @objc func showPrefs() {
        NSApp.unhide(nil); NSApp.activate(ignoringOtherApps: true)   // accessory apps only come forward when forced (cooperative activate is often refused)
        prefs.center(); prefs.makeKeyAndOrderFront(nil)
    }
    @objc func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func plusMinus(_ s: NSSegmentedControl) {
        if s.selectedSegment == 0 { recordMode = true; showGrid() }
        else if presetTable.selectedRow >= 0 { presets.remove(at: presetTable.selectedRow) }
    }
    @objc func pickTheme(_ p: NSPopUpButton) {   // the last item has no theme: it opens the folder
        if let id = p.selectedItem?.representedObject as? String { defaults.set(id, forKey: "theme") }
        else { try? FileManager.default.createDirectory(at: themesFolder, withIntermediateDirectories: true); NSWorkspace.shared.open(themesFolder) }
        refreshThemes()
    }
    @objc func editTheme() {
        var id = themeID
        if isBuiltin(id) {   // built-in themes cannot change: edit a copy and switch to that
            do { id = try copyTheme(id) } catch { alert(error.localizedDescription); return }
            defaults.set(id, forKey: "theme"); refreshThemes()
        }
        let file = themesFolder.appendingPathComponent(id)
        if !NSWorkspace.shared.open(file) { NSWorkspace.shared.activateFileViewerSelecting([file]) }
    }
    @objc func toggleLogin(_ item: NSMenuItem) {
        let svc = SMAppService.mainApp
        try? (svc.status == .enabled ? svc.unregister() : svc.register())
        item.state = svc.status == .enabled ? .on : .off
    }
}
let actions = MenuActions()

final class PresetTable: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in t: NSTableView) -> Int { presets.count }
    func tableView(_ t: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        let p = presets[row]
        switch col?.identifier.rawValue {
        case "name":
            let f = NSTextField(string: p.name)
            f.isBordered = false; f.drawsBackground = false; f.cell?.sendsActionOnEndEditing = true
            f.target = self; f.action = #selector(rename); return f
        case "n":
            let f = NSTextField(labelWithString: row < 9 ? "\(row + 1)" : "")
            f.alignment = .center; f.textColor = .secondaryLabelColor; return f
        case "key":
            let b = ShortcutButton.make(p.combo, clearable: true)
            b.controlSize = .small; b.font = .systemFont(ofSize: NSFont.smallSystemFontSize); b.bezelStyle = .inline
            b.onChange = { [unowned b] in
                if let c = b.combo, let why = conflict(c.code, c.mods, excluding: row) { alert(why); b.combo = p.combo; return }
                presets[row].combo = b.combo
            }
            return b
        default:   // region: size and top-left as percentages of the screen
            return NSTextField(labelWithString: String(format: "%.0f×%.0f%% at %.0f,%.0f", p.w * 100, p.h * 100, p.x * 100, (1 - p.y - p.h) * 100))
        }
    }
    func tableView(_ t: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? { String(row) as NSString }
    func tableView(_ t: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation op: NSTableView.DropOperation) -> NSDragOperation {
        info.draggingSource as? NSTableView === t && op == .above ? .move : []
    }
    func tableView(_ t: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation op: NSTableView.DropOperation) -> Bool {
        guard let from = info.draggingPasteboard.string(forType: .string).flatMap({ Int($0) }) else { return false }
        movePreset(from, to: row); return true
    }
    @objc func rename(_ f: NSTextField) {
        let row = presetTable.row(for: f)
        guard row >= 0, row < presets.count, presets[row].name != f.stringValue else { return }
        presets[row].name = f.stringValue
    }
}
let tableSource = PresetTable()
let presetTable: NSTableView = {
    let t = NSTableView()
    for (id, title, w) in [("n", "#", 16), ("name", "Name", 122), ("region", "Region", 125), ("key", "Shortcut", 92)] as [(String, String, CGFloat)] {
        let c = NSTableColumn(identifier: .init(id)); c.title = title; c.width = w; t.addTableColumn(c)
        if id == "n" { c.minWidth = w; c.maxWidth = w; c.headerToolTip = "Press this number on the grid to apply the preset. Drag rows to reorder." }
    }
    t.registerForDraggedTypes([.string])
    t.dataSource = tableSource; t.delegate = tableSource; t.rowHeight = 26
    t.columnAutoresizingStyle = .uniformColumnAutoresizingStyle; t.usesAlternatingRowBackgroundColors = true
    return t
}()

func settingRow(_ label: String, key: String, y: CGFloat, min: Double, max: Double, step: Double, unit: String = "") -> [NSView] {
    let caption = NSTextField(labelWithString: label)
    caption.frame = NSRect(x: 20, y: y + 6, width: 90, height: 20); caption.alignment = .right
    let field = NSTextField(frame: NSRect(x: 120, y: y + 3, width: 50, height: 24))
    let fmt = NumberFormatter(); fmt.minimum = min as NSNumber; fmt.maximum = max as NSNumber; field.formatter = fmt   // typed values obey the bounds too
    let stepper = NSStepper(frame: NSRect(x: 172, y: y, width: 20, height: 28))
    stepper.minValue = min; stepper.maxValue = max; stepper.increment = step
    for c in [field, stepper] as [NSControl] { c.bind(.value, to: NSUserDefaultsController.shared, withKeyPath: "values." + key, options: nil) }
    let unitLabel = NSTextField(labelWithString: unit); unitLabel.frame = NSRect(x: 198, y: y + 6, width: 80, height: 20)
    return [caption, field, stepper, unitLabel]
}

func shortcutRow(_ current: @escaping () -> (code: Int, mods: Int, label: String), keys: (String, String, String), isMain: Bool, y: CGFloat) -> ShortcutButton {
    let b = ShortcutButton.make(current())
    b.frame = NSRect(x: 115, y: y, width: 160, height: 32)
    b.onChange = { [unowned b] in
        guard let c = b.combo else { return }
        if let why = conflict(c.code, c.mods, checkMain: !isMain, checkUndo: isMain) { alert(why); b.combo = current(); return }
        defaults.set(c.code, forKey: keys.0); defaults.set(c.mods, forKey: keys.1); defaults.set(c.label, forKey: keys.2)
        refreshUndoItem()
    }
    return b
}
let shortcut = shortcutRow({ mainCombo }, keys: ("keyCode", "keyMods", "keyLabel"), isMain: true, y: 652)
let undoShortcut = shortcutRow({ undoCombo }, keys: ("undoCode", "undoMods", "undoLabel"), isMain: false, y: 612)

let themePopup: NSPopUpButton = {
    let p = NSPopUpButton(frame: NSRect(x: 117, y: 440, width: 180, height: 26))
    p.target = actions; p.action = #selector(MenuActions.pickTheme); return p
}()
let themeEdit: NSButton = {
    let b = NSButton(title: "", target: actions, action: #selector(MenuActions.editTheme))
    b.frame = NSRect(x: 305, y: 437, width: 130, height: 32)
    b.toolTip = "A theme is a file you can change in a text editor. A built-in theme is copied first. Open the grid to see your changes."
    return b
}()
let themeNote: NSTextField = {   // what is wrong with the chosen theme's file, empty when nothing is
    let f = NSTextField(labelWithString: "")
    f.frame = NSRect(x: 120, y: 414, width: 320, height: 16); f.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    f.textColor = .systemRed; f.lineBreakMode = .byTruncatingTail; return f
}()
func refreshThemes() {   // the folder can change behind our back, so the menu is rebuilt whenever Settings comes forward
    let id = themeID, menu = NSMenu()
    func add(_ title: String, _ id: String?) { menu.addItem(withTitle: title, action: nil, keyEquivalent: "").representedObject = id }
    for t in builtinThemes { add(t.name, t.name) }
    menu.addItem(.separator())
    for f in userThemes { add(String(f.dropLast(5)), f) }
    if menu.items.last?.isSeparatorItem == false { menu.addItem(.separator()) }
    add("Open Themes Folder", nil)
    themePopup.menu = menu; themePopup.selectItem(at: themePopup.indexOfItem(withRepresentedObject: id))
    themeEdit.title = isBuiltin(id) ? "Edit a Copy…" : "Edit…"
    let problem = themeProblem(id)
    themeNote.stringValue = problem.map { "Not in use: \($0)" } ?? ""; themeNote.toolTip = problem
}

let prefs: NSWindow = {
    let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 704), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    w.title = "GridSnap Settings"
    w.isReleasedWhenClosed = false
    let caption = NSTextField(labelWithString: "Show grid:")
    caption.frame = NSRect(x: 20, y: 658, width: 90, height: 20); caption.alignment = .right
    let appearanceCaption = NSTextField(labelWithString: "Appearance:")
    appearanceCaption.frame = NSRect(x: 20, y: 476, width: 90, height: 20); appearanceCaption.alignment = .right
    let appearance = NSPopUpButton(frame: NSRect(x: 117, y: 474, width: 180, height: 26))
    for (i, title) in ["Match System", "Light", "Dark"].enumerated() { appearance.addItem(withTitle: title); appearance.lastItem?.tag = i }
    appearance.bind(.selectedTag, to: NSUserDefaultsController.shared, withKeyPath: "values.appearance", options: nil)
    appearance.toolTip = "Every theme has a light and a dark version."
    let themeCaption = NSTextField(labelWithString: "Theme:")
    themeCaption.frame = NSRect(x: 20, y: 442, width: 90, height: 20); themeCaption.alignment = .right
    let showCaption = NSTextField(labelWithString: "Show:")
    showCaption.frame = NSRect(x: 20, y: 384, width: 90, height: 20); showCaption.alignment = .right
    let headerCheck = NSButton(checkboxWithTitle: "App icon and name", target: nil, action: nil)
    let listCheck = NSButton(checkboxWithTitle: "Preset list", target: nil, action: nil)
    headerCheck.frame = NSRect(x: 118, y: 384, width: 170, height: 20); headerCheck.toolTip = "The app whose window will move, above the cells."
    listCheck.frame = NSRect(x: 118, y: 360, width: 170, height: 20)
    listCheck.toolTip = "The first nine presets, under the cells. Keys 1 to 9 apply them whether or not the list is shown."
    for (c, key) in [(headerCheck, "showHeader"), (listCheck, "showList")] { c.bind(.value, to: NSUserDefaultsController.shared, withKeyPath: "values." + key, options: nil) }
    let targetCaption = NSTextField(labelWithString: "Target:")
    targetCaption.frame = NSRect(x: 20, y: 326, width: 90, height: 20); targetCaption.alignment = .right
    let focusedRadio = NSButton(radioButtonWithTitle: "Focused window", target: actions, action: #selector(MenuActions.pickTarget))
    let cursorRadio = NSButton(radioButtonWithTitle: "Window under cursor", target: actions, action: #selector(MenuActions.pickTarget))
    focusedRadio.frame = NSRect(x: 118, y: 326, width: 170, height: 20)
    cursorRadio.frame = NSRect(x: 118, y: 302, width: 170, height: 20); cursorRadio.tag = 1
    cursorRadio.toolTip = "Snap whatever window is under the mouse when the shortcut is pressed."
    (defaults.bool(forKey: "underCursor") ? cursorRadio : focusedRadio).state = .on   // same action + superview = one radio group
    let presetsCaption = NSTextField(labelWithString: "Presets")
    presetsCaption.frame = NSRect(x: 20, y: 274, width: 200, height: 20); presetsCaption.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
    let scroll = NSScrollView(frame: NSRect(x: 20, y: 48, width: 420, height: 218))
    scroll.documentView = presetTable; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
    presetTable.autoresizingMask = [.width]; presetTable.sizeLastColumnToFit()   // never wider than the visible area
    let plusMinus = NSSegmentedControl(labels: ["+", "−"], trackingMode: .momentary, target: actions, action: #selector(MenuActions.plusMinus))
    plusMinus.frame = NSRect(x: 20, y: 16, width: 70, height: 24)
    plusMinus.setToolTip("Opens the grid: drag a region to save it as a preset. Shift-release on the grid does the same.", forSegment: 0)
    plusMinus.setToolTip("Removes the selected preset.", forSegment: 1)
    let undoCaption = NSTextField(labelWithString: "Undo snap:")
    undoCaption.frame = NSRect(x: 20, y: 618, width: 90, height: 20); undoCaption.alignment = .right
    let views = [caption, shortcut, undoCaption, undoShortcut, appearanceCaption, appearance, themeCaption, themePopup, themeEdit, themeNote,
                 showCaption, headerCheck, listCheck, targetCaption, focusedRadio, cursorRadio, presetsCaption, scroll, plusMinus]
        + settingRow("Columns:", key: "cols", y: 572, min: 1, max: 24, step: 1)
        + settingRow("Rows:", key: "rows", y: 538, min: 1, max: 24, step: 1)
        + settingRow("Gap:", key: "gap", y: 504, min: 0, max: 64, step: 2, unit: "points")
    for v in views { w.contentView?.addSubview(v) }
    NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: w, queue: nil) { _ in refreshThemes() }
    NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: nil) { _ in
        ShortcutButton.active?.cancelRecording(); NSApp.hide(nil)   // give focus back
    }
    return w
}()
