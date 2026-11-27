import Cocoa

// The part of each display that windows may use: all of it but the menu bar and the Dock.
//
// NSScreen.visibleFrame should be that, and with several displays it can be wrong. The Dock moves to another display and
// macOS keeps its strip on the display it left, and reports the display it is on now as free down to the edge, until the
// Dock restarts. A window snapped there ends up under the Dock. The Dock's own window covers the display the Dock is on,
// whatever visibleFrame says, so that window decides which display gives up the strip.

struct DockStrip {   // the display the Dock is on, and how far the Dock reaches in from each edge of it
    var display: NSRect
    var left: CGFloat, bottom: CGFloat, right: CGFloat
}

func usableArea(frame: NSRect, visible: NSRect, dock: DockStrip?) -> NSRect {
    guard let dock else { return visible }   // not clear where the Dock is: take visibleFrame as it comes
    var r = frame
    r.size.height = visible.maxY - frame.minY   // the menu bar does not move; the top stays as reported
    guard frame == dock.display else { return r }
    return NSRect(x: r.minX + dock.left, y: r.minY + dock.bottom, width: r.width - dock.left - dock.right, height: r.height - dock.bottom)
}

extension NSScreen {
    var usableFrame: NSRect { usableArea(frame: frame, visible: visibleFrame, dock: dockStrip()) }
}

// Looked up at most twice a second: one snap asks for the usable frame several times, and an open grid asks on every redraw.
private var dockSeen: (at: TimeInterval, strip: DockStrip?)?
private func dockStrip() -> DockStrip? {
    let now = ProcessInfo.processInfo.systemUptime
    if let d = dockSeen, now - d.at < 0.5 { return d.strip }
    let screens = NSScreen.screens
    // The Dock is as thick on one display as on another, so the widest strip reported anywhere is the one it takes.
    func widest(_ strip: (NSScreen) -> CGFloat) -> CGFloat { max(screens.map(strip).max() ?? 0, 0) }
    let strip = dockDisplay(among: screens.map(\.frame)).map {
        DockStrip(display: $0, left: widest { $0.visibleFrame.minX - $0.frame.minX }, bottom: widest { $0.visibleFrame.minY - $0.frame.minY },
                  right: widest { $0.frame.maxX - $0.visibleFrame.maxX })
    }
    dockSeen = (now, strip)
    return strip
}
// The frame of the one display the Dock's window covers. nil with a single display, where the strip has nowhere else to
// be, and when the Dock has no window on screen or has one on several displays.
private func dockDisplay(among screens: [NSRect]) -> NSRect? {
    guard screens.count > 1, let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
    let top = screens[0].maxY, level = Int(CGWindowLevelForKey(.dockWindow))   // window bounds have their origin at the top-left of the primary screen
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    var covered: [NSRect] = []
    for w in windows where w[kCGWindowOwnerPID as String] as? pid_t == dock.processIdentifier && w[kCGWindowLayer as String] as? Int == level {
        guard let b = w[kCGWindowBounds as String], let r = CGRect(dictionaryRepresentation: b as! CFDictionary) else { continue }
        let f = NSRect(x: r.minX, y: top - r.maxY, width: r.width, height: r.height)
        if screens.contains(f), !covered.contains(f) { covered.append(f) }
    }
    return covered.count == 1 ? covered[0] : nil
}

func screenUnderCursor() -> NSScreen { NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? .main! }

// A frame on a display and the fraction of the display's usable area it covers, one from the other.
func screenFrame(fraction r: NSRect, on screen: NSScreen) -> NSRect {
    let g = CGFloat(max(defaults.double(forKey: "gap"), 0)) / 2   // half on the screen edge, half on each frame = one gap everywhere
    let f = screen.usableFrame.insetBy(dx: g, dy: g)
    return NSRect(x: f.minX + r.minX * f.width, y: f.minY + r.minY * f.height,
                  width: r.width * f.width, height: r.height * f.height).insetBy(dx: g, dy: g)
}
func screenFraction(of r: NSRect, on screen: NSScreen) -> NSRect {
    let g = CGFloat(max(defaults.double(forKey: "gap"), 0)) / 2
    let f = screen.usableFrame.insetBy(dx: g, dy: g), r = r.insetBy(dx: -g, dy: -g)
    guard f.width > 0, f.height > 0 else { return .null }
    return NSRect(x: (r.minX - f.minX) / f.width, y: (r.minY - f.minY) / f.height, width: r.width / f.width, height: r.height / f.height)
        .intersection(NSRect(x: 0, y: 0, width: 1, height: 1))
}
