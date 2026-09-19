import Cocoa

var targetWindow: AXUIElement?
var targetScreen: NSScreen = .main!
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

var lastSnap: (win: AXUIElement, pos: CGPoint, size: CGSize)?
func undoSnap() {
    guard let s = lastSnap else { return }
    lastSnap = axFrame(s.win).map { (s.win, $0.0, $0.1) }   // pressing again redoes
    axSet(s.win, s.pos, s.size)
}
