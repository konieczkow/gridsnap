// gridsnap — hotkey, drag a grid, focused window snaps to it. Build: ./build.sh
import Cocoa
import Carbon
import ServiceManagement

let cols = 12, rows = 8
// ponytail: fixed grid; the hotkey lives in UserDefaults (keyCode/keyMods/keyLabel), default ⌃⌥D

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

guard AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) else {
    print("Grant Accessibility permission in System Settings, then relaunch."); exit(1)
}

var targetWindow: AXUIElement?
var targetScreen: NSScreen = .main!

func focusedWindow() -> AXUIElement? {
    guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, &ref) == .success,
          let w = ref else { return nil }
    return (w as! AXUIElement)
}

func axSet(_ win: AXUIElement, _ pos: CGPoint, _ size: CGSize) {
    var pos = pos, size = size
    // ponytail: position then size; add a second position pass if a window lands off-screen when crossing displays
    AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
    AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
}
func axFrame(_ win: AXUIElement) -> (CGPoint, CGSize)? {
    var p: CFTypeRef?, s: CFTypeRef?
    guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &p) == .success,
          AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &s) == .success else { return nil }
    var pos = CGPoint.zero, size = CGSize.zero
    AXValueGetValue(p as! AXValue, .cgPoint, &pos); AXValueGetValue(s as! AXValue, .cgSize, &size)
    return (pos, size)
}
func applyFrame(_ win: AXUIElement, _ r: NSRect) {
    axSet(win, CGPoint(x: r.minX, y: NSScreen.screens[0].frame.maxY - r.maxY), CGSize(width: r.width, height: r.height)) // AX origin is top-left of primary screen
}

final class GridView: NSView {
    var start: (Int, Int)?, end: (Int, Int)?
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }

    var grid: NSRect { bounds.insetBy(dx: 10, dy: 10) }
    func cell(_ e: NSEvent) -> (Int, Int) {
        let p = convert(e.locationInWindow, from: nil)
        return (min(max(Int((p.x - grid.minX) / grid.width * CGFloat(cols)), 0), cols - 1),
                min(max(Int((p.y - grid.minY) / grid.height * CGFloat(rows)), 0), rows - 1))
    }
    var selection: (x: ClosedRange<Int>, y: ClosedRange<Int>)? {
        guard let s = start, let e = end else { return nil }
        return (min(s.0, e.0)...max(s.0, e.0), min(s.1, e.1)...max(s.1, e.1))
    }

    var original: (CGPoint, CGSize)?   // window frame at mouse-down, restored on cancel
    var selectionFrame: NSRect? {
        guard let sel = selection else { return nil }
        let f = targetScreen.visibleFrame, cw = f.width / CGFloat(cols), ch = f.height / CGFloat(rows)
        return NSRect(x: f.minX + CGFloat(sel.x.lowerBound) * cw, y: f.minY + CGFloat(sel.y.lowerBound) * ch,
                      width: CGFloat(sel.x.count) * cw, height: CGFloat(sel.y.count) * ch)
    }
    func preview() {   // live: the window follows the selection and snaps back when there is none
        guard let win = targetWindow else { return }
        if let r = selectionFrame { applyFrame(win, r) } else if let o = original { axSet(win, o.0, o.1) }
    }

    override func mouseDown(with e: NSEvent) {
        original = targetWindow.flatMap(axFrame)
        start = cell(e); end = start; needsDisplay = true; preview()
    }
    func track(_ e: NSEvent) {   // cursor outside the panel = no selection, so releasing there cancels
        let new = bounds.contains(convert(e.locationInWindow, from: nil)) ? cell(e) : nil
        guard new?.0 != end?.0 || new?.1 != end?.1 else { return }   // only hit AX when the cell changes
        end = new; needsDisplay = true; preview()
    }
    override func mouseDragged(with e: NSEvent) { track(e) }
    override func mouseUp(with e: NSEvent) { track(e); hideGrid() }
    override func keyDown(with e: NSEvent) { if e.keyCode == 53 { start = nil; end = nil; preview(); hideGrid() } } // esc, also mid-drag

    override func draw(_ dirty: NSRect) {
        guard !grid.isEmpty else { return }   // layer-backed views get drawn at zero size before the panel is shown
        let cw = grid.width / CGFloat(cols), ch = grid.height / CGFloat(rows)
        // extra gap at boundary i of n: halves widest, thirds/quarters narrower, everything else uniform
        func gap(_ i: Int, _ n: Int) -> CGFloat {
            i == 0 || i == n ? 0 : (i * 2) % n == 0 ? 3 : (i * 3) % n == 0 || (i * 4) % n == 0 ? 1.5 : 0
        }
        func rect(_ x: ClosedRange<Int>, _ y: ClosedRange<Int>) -> NSBezierPath {
            let x0 = grid.minX + CGFloat(x.lowerBound) * cw + 2 + gap(x.lowerBound, cols)
            let x1 = grid.minX + CGFloat(x.upperBound + 1) * cw - 2 - gap(x.upperBound + 1, cols)
            let y0 = grid.minY + CGFloat(y.lowerBound) * ch + 2 + gap(y.lowerBound, rows)
            let y1 = grid.minY + CGFloat(y.upperBound + 1) * ch - 2 - gap(y.upperBound + 1, rows)
            return NSBezierPath(roundedRect: NSRect(x: x0, y: y0, width: max(x1 - x0, 0), height: max(y1 - y0, 0)), xRadius: 4, yRadius: 4)
        }
        for x in 0..<cols { for y in 0..<rows {
            let p = rect(x...x, y...y)
            NSColor.white.withAlphaComponent(0.10).setFill(); p.fill()
            NSColor.white.withAlphaComponent(0.20).setStroke(); p.stroke()
        }}
        if let s = selection {
            let p = rect(s.x, s.y)
            NSColor.controlAccentColor.withAlphaComponent(0.85).setFill(); p.fill()
            NSColor.white.withAlphaComponent(0.7).setStroke(); p.lineWidth = 1.5; p.stroke()
        }
    }
}

final class Panel: NSPanel { override var canBecomeKey: Bool { true } }

let view = GridView()
let panel = Panel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
let glass: NSView
if #available(macOS 26, *) {
    let g = NSGlassEffectView(); g.cornerRadius = 18; g.contentView = view; glass = g
    g.wantsLayer = true; g.layer?.cornerRadius = 18; g.layer?.masksToBounds = true  // clip the backdrop too
} else {
    let v = NSVisualEffectView(); v.material = .hudWindow; v.state = .active
    v.wantsLayer = true; v.layer?.cornerRadius = 18; v.addSubview(view); glass = v
}
panel.contentView = glass
panel.appearance = NSAppearance(named: .darkAqua)
panel.hasShadow = false  // a shadow is computed on the square bounds and leaks through the corners
panel.level = .floating
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hidesOnDeactivate = false
panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]

func showGrid() {
    targetWindow = focusedWindow()   // grab it before the panel appears
    targetScreen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? .main!
    view.start = nil; view.end = nil; view.original = nil; view.needsDisplay = true
    let f = targetScreen.visibleFrame, w: CGFloat = 480, h = w * f.height / f.width
    panel.setFrame(NSRect(x: f.midX - w / 2, y: f.midY - h / 2, width: w, height: h), display: true)
    view.frame = glass.bounds
    panel.alphaValue = 0
    panel.makeKeyAndOrderFront(nil)
    panel.makeFirstResponder(view)
    NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }
}
func hideGrid() {
    NSAnimationContext.runAnimationGroup({ $0.duration = 0.10; panel.animator().alphaValue = 0 }) { panel.orderOut(nil) }
}

// clicks on other apps never reach the panel; a global monitor sees them and dismisses
NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in if panel.isVisible { hideGrid() } }

let defaults = UserDefaults.standard
var hotKeyRef: EventHotKeyRef?
func registerHotKey() {
    if let r = hotKeyRef { UnregisterEventHotKey(r); hotKeyRef = nil }
    let code = UInt32(defaults.object(forKey: "keyCode") as? Int ?? kVK_ANSI_D)
    let mods = UInt32(defaults.object(forKey: "keyMods") as? Int ?? (optionKey | controlKey))
    RegisterEventHotKey(code, mods, EventHotKeyID(signature: 0x4753_4E50, id: 1), GetApplicationEventTarget(), 0, &hotKeyRef)
}
var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
    if panel.isVisible { hideGrid() } else { showGrid() }
    return noErr
}, 1, &spec, nil, nil)
registerHotKey()

// preferences: one window, one button that records the next key combo
final class ShortcutButton: NSButton {
    var recording = false
    override var acceptsFirstResponder: Bool { true }
    func refresh() { title = recording ? "Type shortcut…" : defaults.string(forKey: "keyLabel") ?? "⌃⌥D" }
    @objc func startRecording() {
        recording = true; refresh(); window?.makeFirstResponder(self)
        if let r = hotKeyRef { UnregisterEventHotKey(r); hotKeyRef = nil }   // so the old combo reaches us
    }
    override func keyDown(with e: NSEvent) {
        guard recording else { return super.keyDown(with: e) }
        let f = e.modifierFlags.intersection([.command, .option, .control, .shift])
        if e.keyCode != 53 && !f.isEmpty {   // esc or a bare key keeps the old shortcut
            var mods = 0, label = ""
            for (flag, mod, sym) in [(NSEvent.ModifierFlags.control, controlKey, "⌃"), (.option, optionKey, "⌥"),
                                     (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")] where f.contains(flag) { mods |= mod; label += sym }
            defaults.set(Int(e.keyCode), forKey: "keyCode"); defaults.set(mods, forKey: "keyMods")
            defaults.set(label + (e.charactersIgnoringModifiers?.uppercased() ?? "?"), forKey: "keyLabel")
        }
        recording = false; refresh(); registerHotKey()
    }
}
let prefs = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 90), styleMask: [.titled, .closable], backing: .buffered, defer: false)
prefs.title = "GridSnap"
prefs.isReleasedWhenClosed = false
let caption = NSTextField(labelWithString: "Show grid:")
caption.frame = NSRect(x: 20, y: 36, width: 90, height: 20); caption.alignment = .right
let shortcut = ShortcutButton(title: "", target: nil, action: nil)
shortcut.frame = NSRect(x: 115, y: 30, width: 160, height: 32); shortcut.refresh()
shortcut.target = shortcut; shortcut.action = #selector(ShortcutButton.startRecording)
prefs.contentView?.addSubview(caption); prefs.contentView?.addSubview(shortcut)
NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: prefs, queue: nil) { _ in NSApp.hide(nil) }   // give focus back

final class MenuActions: NSObject {
    @objc func showPrefs() { prefs.center(); prefs.makeKeyAndOrderFront(nil); NSApp.activate() }
    @objc func toggleLogin(_ item: NSMenuItem) {
        let svc = SMAppService.mainApp
        try? (svc.status == .enabled ? svc.unregister() : svc.register())
        item.state = svc.status == .enabled ? .on : .off
    }
}
let actions = MenuActions()
let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
status.button?.image = NSImage(systemSymbolName: "square.grid.3x2", accessibilityDescription: "GridSnap")
let menu = NSMenu()
menu.addItem(withTitle: "Shortcut…", action: #selector(MenuActions.showPrefs), keyEquivalent: "").target = actions
let login = menu.addItem(withTitle: "Launch at Login", action: #selector(MenuActions.toggleLogin), keyEquivalent: "")
login.target = actions
login.state = SMAppService.mainApp.status == .enabled ? .on : .off
menu.addItem(.separator())
menu.addItem(withTitle: "Quit GridSnap", action: #selector(NSApplication.terminate), keyEquivalent: "q")
status.menu = menu

app.run()
