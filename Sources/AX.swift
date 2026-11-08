import Cocoa

var targetWindow: AXUIElement?
var targetApp: NSRunningApplication?   // the app behind targetWindow; its icon and name head every panel, like Divvy
var recordMode = false   // grid open only to pick a region for a new preset; nothing moves

func focusedWindow() -> AXUIElement? {
    guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, &ref) == .success,
          let w = ref else { return nil }
    return (w as! AXUIElement)
}

func windowUnderCursor() -> AXUIElement? {
    let m = NSEvent.mouseLocation
    var hit: AXUIElement?
    guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(m.x), Float(NSScreen.screens[0].frame.maxY - m.y), &hit) == .success,
          let el = hit else { return nil }
    var win: CFTypeRef?
    if AXUIElementCopyAttributeValue(el, kAXWindowAttribute as CFString, &win) == .success, let w = win { return (w as! AXUIElement) }
    var role: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role)
    return (role as? String) == kAXWindowRole ? el : nil   // the hit was the window itself
}

func pickTarget() -> AXUIElement? { (defaults.bool(forKey: "underCursor") ? windowUnderCursor() : nil) ?? focusedWindow() }
func appOf(_ win: AXUIElement) -> NSRunningApplication? { var pid: pid_t = 0; AXUIElementGetPid(win, &pid); return NSRunningApplication(processIdentifier: pid) }
func screenUnderCursor() -> NSScreen { NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? .main! }

func axSet(_ win: AXUIElement, _ pos: CGPoint, _ size: CGSize? = nil) {
    var pos = pos
    AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
    if var size { AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!) }
}
func axFrame(_ win: AXUIElement) -> (CGPoint, CGSize)? {
    var p: CFTypeRef?, s: CFTypeRef?
    guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &p) == .success,
          AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &s) == .success else { return nil }
    var pos = CGPoint.zero, size = CGSize.zero
    AXValueGetValue(p as! AXValue, .cgPoint, &pos); AXValueGetValue(s as! AXValue, .cgSize, &size)
    return (pos, size)
}
func screenOf(_ win: AXUIElement) -> NSScreen {   // the screen holding the window's centre
    guard let f = axFrame(win) else { return .main! }
    let c = NSPoint(x: f.0.x + f.1.width / 2, y: NSScreen.screens[0].frame.maxY - f.0.y - f.1.height / 2)
    return NSScreen.screens.first { NSMouseInRect(c, $0.frame, false) } ?? .main!
}
func applyFrame(_ win: AXUIElement, _ r: NSRect) {
    let top = NSScreen.screens[0].frame.maxY   // AX origin is top-left of primary screen
    let pos = CGPoint(x: r.minX, y: top - r.maxY)
    axSet(win, pos, CGSize(width: r.width, height: r.height))
    guard let f = axFrame(win),
          let v = NSScreen.screens.first(where: { NSMouseInRect(NSPoint(x: r.midX, y: r.midY), $0.frame, false) })?.visibleFrame else { return }
    let fit = CGPoint(x: max(min(pos.x, v.maxX - f.1.width), v.minX), y: max(min(pos.y, top - v.minY - f.1.height), top - v.maxY))
    if abs(fit.x - f.0.x) > 1 || abs(fit.y - f.0.y) > 1 { axSet(win, fit) }
}
func screenFrame(fraction r: NSRect, on screen: NSScreen) -> NSRect {
    let g = CGFloat(max(defaults.double(forKey: "gap"), 0)) / 2   // half on the screen edge, half on each frame = one gap everywhere
    let f = screen.visibleFrame.insetBy(dx: g, dy: g)
    return NSRect(x: f.minX + r.minX * f.width, y: f.minY + r.minY * f.height,
                  width: r.width * f.width, height: r.height * f.height).insetBy(dx: g, dy: g)
}
func screenFraction(of r: NSRect, on screen: NSScreen) -> NSRect {
    let g = CGFloat(max(defaults.double(forKey: "gap"), 0)) / 2
    let f = screen.visibleFrame.insetBy(dx: g, dy: g), r = r.insetBy(dx: -g, dy: -g)
    guard f.width > 0, f.height > 0 else { return .null }
    return NSRect(x: (r.minX - f.minX) / f.width, y: (r.minY - f.minY) / f.height, width: r.width / f.width, height: r.height / f.height)
        .intersection(NSRect(x: 0, y: 0, width: 1, height: 1))
}

var snapped: [AXUIElement] = []
func remember(_ win: AXUIElement) { if !snapped.contains(where: { CFEqual($0, win) }) { snapped.append(win) } }
func forget(_ win: AXUIElement) { snapped.removeAll { CFEqual($0, win) } }
func ghostFrames() -> [NSRect] {   // snapped windows still at their snapped frame, in screen coordinates, the target excluded
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    var onScreen: [(pid: pid_t, bounds: CGRect)] = info.compactMap {
        guard let pid = $0[kCGWindowOwnerPID as String] as? pid_t, let b = $0[kCGWindowBounds as String],
              let r = CGRect(dictionaryRepresentation: b as! CFDictionary) else { return nil }
        return (pid, r)
    }
    guard !onScreen.isEmpty, !snapped.isEmpty else { return [] }
    func claim(_ pid: pid_t, _ f: CGRect) -> Bool {
        guard let i = onScreen.firstIndex(where: { $0.pid == pid && abs($0.bounds.minX - f.minX) <= 2 && abs($0.bounds.minY - f.minY) <= 2
                                                     && abs($0.bounds.width - f.width) <= 2 && abs($0.bounds.height - f.height) <= 2 }) else { return false }
        onScreen.remove(at: i); return true
    }
    let top = NSScreen.screens[0].frame.maxY, target = targetWindow.map { [$0] } ?? []
    var out: [NSRect] = [], stuck: Set<pid_t> = []
    for (i, win) in (target + snapped.filter { w in !target.contains { CFEqual($0, w) } }).enumerated() {
        var pid: pid_t = 0
        AXUIElementGetPid(win, &pid)
        guard let app = NSRunningApplication(processIdentifier: pid) else { forget(win); continue }
        if app.isHidden || stuck.contains(pid) { continue }
        AXUIElementSetMessagingTimeout(win, 0.2)
        var p: CFTypeRef?, s: CFTypeRef?
        var err = AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &p)
        if err == .success { err = AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &s) }
        AXUIElementSetMessagingTimeout(win, 0)
        if err == .invalidUIElement { forget(win) }
        if err == .cannotComplete { stuck.insert(pid) }
        guard err == .success else { continue }
        var f = CGRect.zero
        AXValueGetValue(p as! AXValue, .cgPoint, &f.origin); AXValueGetValue(s as! AXValue, .cgSize, &f.size)
        guard claim(pid, f), i >= target.count else { continue }
        let r = NSRect(x: f.minX, y: top - f.maxY, width: f.width, height: f.height)
        if !out.contains(r) { out.append(r) }
    }
    return out
}

var lastSnap: (win: AXUIElement, pos: CGPoint, size: CGSize)?
func undoSnap() {
    cancelGrid()
    guard let s = lastSnap else { return }
    lastSnap = axFrame(s.win).map { (s.win, $0.0, $0.1) }   // pressing again redoes
    axSet(s.win, s.pos, s.size)
}
