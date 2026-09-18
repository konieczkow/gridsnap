import Cocoa
import ServiceManagement

final class MenuActions: NSObject {
    @objc func undo() { undoSnap() }
    @objc func applyPresetItem(_ item: NSMenuItem) { if item.tag < presets.count { applyPreset(presets[item.tag]) } }
    @objc func pickTarget(_ b: NSButton) { defaults.set(b.tag == 1, forKey: "underCursor") }
    @objc func showPrefs() { prefs.center(); prefs.makeKeyAndOrderFront(nil); NSApp.activate() }
    @objc func plusMinus(_ s: NSSegmentedControl) {
        if s.selectedSegment == 0 { recordMode = true; showGrid() }
        else if presetTable.selectedRow >= 0 { presets.remove(at: presetTable.selectedRow) }
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
        case "key":
            let b = ShortcutButton.make((p.keyCode, p.keyMods, p.keyLabel))
            b.controlSize = .small; b.font = .systemFont(ofSize: NSFont.smallSystemFontSize); b.bezelStyle = .inline
            b.onChange = { [unowned b] in
                guard let c = b.combo else { return }
                if let why = conflict(c.code, c.mods, excluding: row) { alert(why); b.combo = (p.keyCode, p.keyMods, p.keyLabel); return }
                presets[row].keyCode = c.code; presets[row].keyMods = c.mods; presets[row].keyLabel = c.label
            }
            return b
        default:   // region: size and top-left as percentages of the screen
            return NSTextField(labelWithString: String(format: "%.0f×%.0f%% at %.0f,%.0f", p.w * 100, p.h * 100, p.x * 100, (1 - p.y - p.h) * 100))
        }
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
    for (id, title, w) in [("name", "Name", 150), ("region", "Region", 140), ("key", "Shortcut", 110)] as [(String, String, CGFloat)] {
        let c = NSTableColumn(identifier: .init(id)); c.title = title; c.width = w; t.addTableColumn(c)
    }
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

let shortcut: ShortcutButton = {
    let b = ShortcutButton.make(mainCombo)
    b.frame = NSRect(x: 115, y: 468, width: 160, height: 32)
    b.onChange = { [unowned b] in
        guard let c = b.combo else { return }
        if let why = conflict(c.code, c.mods, checkMain: false) { alert(why); b.combo = mainCombo; return }
        defaults.set(c.code, forKey: "keyCode"); defaults.set(c.mods, forKey: "keyMods"); defaults.set(c.label, forKey: "keyLabel")
    }
    return b
}()

let prefs: NSWindow = {
    let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 520), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    w.title = "GridSnap Settings"
    w.isReleasedWhenClosed = false
    let caption = NSTextField(labelWithString: "Show grid:")
    caption.frame = NSRect(x: 20, y: 474, width: 90, height: 20); caption.alignment = .right
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
    let views = [caption, shortcut, targetCaption, focusedRadio, cursorRadio, presetsCaption, scroll, plusMinus]
        + settingRow("Columns:", key: "cols", y: 428, min: 1, max: 24, step: 1)
        + settingRow("Rows:", key: "rows", y: 394, min: 1, max: 24, step: 1)
        + settingRow("Gap:", key: "gap", y: 360, min: 0, max: 64, step: 2, unit: "points")
    for v in views { w.contentView?.addSubview(v) }
    NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: nil) { _ in
        ShortcutButton.active?.cancelRecording(); NSApp.hide(nil)   // give focus back
    }
    return w
}()
