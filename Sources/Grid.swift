import Cocoa
import Carbon

func cellRange(_ lo: CGFloat, _ hi: CGFloat, _ n: Int) -> ClosedRange<Int> {
    let a = Int((lo * CGFloat(n)).rounded()), b = Int((hi * CGFloat(n)).rounded()) - 1
    let c = min(max(Int((lo + hi) / 2 * CGFloat(n)), 0), n - 1)
    return a <= b ? max(a, 0)...min(b, n - 1) : c...c
}

// One grid panel per display while the grid is open, index matching NSScreen.screens. Only one panel holds a
// selection at a time; the window snaps to that panel's display, so a drag on another display moves it there.
var grids: [GridView] = [], spare: [GridView] = []
var gridActive = false
var original: (CGPoint, CGSize)?   // target window frame when the grid opened, restored on cancel
var moved = false, dragging: GridView?
var selected: GridView? { grids.first { $0.selection != nil } }
let presetKeys = [[kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9],
                  [kVK_ANSI_Keypad1, kVK_ANSI_Keypad2, kVK_ANSI_Keypad3, kVK_ANSI_Keypad4, kVK_ANSI_Keypad5,
                   kVK_ANSI_Keypad6, kVK_ANSI_Keypad7, kVK_ANSI_Keypad8, kVK_ANSI_Keypad9]]

func preview() {   // live: the window follows the selection and snaps back when there is none
    guard let win = targetWindow else { return }
    if let r = selected?.selectionFrame { applyFrame(win, r); moved = true } else if moved, let o = original { axSet(win, o.0, o.1) }
}
func commitGrid(save: Bool) {
    guard gridActive else { return }
    gridActive = false
    preview()
    if selected != nil, let w = targetWindow { remember(w); if let o = original { lastSnap = (w, o.0, o.1) } }
    let f = (save || recordMode) ? selected?.selectionFraction : nil   // shift saves a preset
    hideGrid()
    if let f { newPreset(f) }
}
func commitGrid(preset p: Preset, on screen: NSScreen) {
    guard gridActive, !recordMode else { return }
    gridActive = false
    if let w = targetWindow {
        applyFrame(w, screenFrame(fraction: p.rect, on: screen)); remember(w)
        if let o = original { lastSnap = (w, o.0, o.1) }
    }
    hideGrid()
}
func cancelGrid() {
    guard gridActive else { return }
    gridActive = false
    grids.forEach { $0.clear() }
    preview(); hideGrid()
}

final class GridView: NSView {
    var screen: NSScreen = .main!
    lazy var panel = makePanel(self)
    var start: (Int, Int)?, end: (Int, Int)?, pending = false
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }

    var headerHeight: CGFloat { targetApp == nil ? 0 : 52 }   // the target app's icon and name; 0 without a target
    var list: [Preset] = [], pressed: Int?
    var listHeight: CGFloat { list.isEmpty ? 0 : CGFloat((list.count + 2) / 3) * 20 + 8 }
    var grid: NSRect { NSRect(x: 10, y: 10 + listHeight, width: bounds.width - 20, height: bounds.height - 20 - listHeight - headerHeight) }
    var cellArea: NSRect { NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - headerHeight) }   // the panel minus the header
    func entryRect(_ i: Int) -> NSRect {
        let w = grid.width / 3
        return NSRect(x: grid.minX + CGFloat(i % 3) * w, y: 10 + CGFloat((list.count - 1) / 3 - i / 3) * 20, width: w, height: 20)
    }
    func entry(_ e: NSEvent) -> Int? { list.indices.first { entryRect($0).contains(convert(e.locationInWindow, from: nil)) } }
    func cell(_ e: NSEvent) -> (Int, Int) {
        let p = convert(e.locationInWindow, from: nil)
        return (min(max(Int((p.x - grid.minX) / grid.width * CGFloat(cols)), 0), cols - 1),
                min(max(Int((p.y - grid.minY) / grid.height * CGFloat(rows)), 0), rows - 1))
    }
    var selection: (x: ClosedRange<Int>, y: ClosedRange<Int>)? {
        guard let s = start, let e = end else { return nil }
        return (min(s.0, e.0)...max(s.0, e.0), min(s.1, e.1)...max(s.1, e.1))
    }
    var selectionFraction: NSRect? {
        guard let s = selection else { return nil }
        return NSRect(x: Double(s.x.lowerBound) / Double(cols), y: Double(s.y.lowerBound) / Double(rows),
                      width: Double(s.x.count) / Double(cols), height: Double(s.y.count) / Double(rows))
    }
    var selectionFrame: NSRect? { selectionFraction.map { screenFrame(fraction: $0, on: screen) } }

    var ghosts: [NSRect] = []
    func clear() { start = nil; end = nil; pending = false; pressed = nil; needsDisplay = true }
    func claim() { for g in grids where g !== self { g.clear() } }   // a selection here drops any on another display

    override func mouseDown(with e: NSEvent) {
        guard gridActive else { return }
        let p = convert(e.locationInWindow, from: nil)
        guard cellArea.contains(p) else { return }   // a click on the header selects nothing
        if p.y < grid.minY - 4 { pressed = entry(e); needsDisplay = true; return }
        dragging = self; claim(); start = cell(e); end = start; pending = false; needsDisplay = true   // no preview yet: one cell is a tiny window, wait for the drag
    }
    func track(_ e: NSEvent) {   // cursor outside the panel or on the header = no selection, so releasing there cancels
        guard gridActive else { return }
        let new = cellArea.contains(convert(e.locationInWindow, from: nil)) ? cell(e) : nil
        guard new?.0 != end?.0 || new?.1 != end?.1 else { return }   // only hit AX when the cell changes
        end = new; needsDisplay = true; preview()
    }
    override func mouseDragged(with e: NSEvent) { if dragging === self { track(e) } }
    override func mouseUp(with e: NSEvent) {
        if let i = pressed, entry(e) == i { commitGrid(preset: list[i], on: screen) }
        pressed = nil; needsDisplay = true
        guard dragging === self else { return }
        dragging = nil; track(e); commitGrid(save: e.modifierFlags.contains(.shift))
    }
    override func keyDown(with e: NSEvent) {
        guard gridActive else { return }
        if e.keyCode == 53 { cancelGrid(); return }   // esc, also mid-drag
        let shift = e.modifierFlags.contains(.shift)
        if e.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           let i = presetKeys.lazy.compactMap({ $0.firstIndex(of: Int(e.keyCode)) }).first {
            if i < presets.count { commitGrid(preset: presets[i], on: screen) }
            return
        }
        switch e.specialKey {
        case .carriageReturn?, .enter?: commitGrid(save: shift)
        case .tab?: focus(1)
        case .backTab?: focus(-1)
        case .leftArrow?: step(-1, 0, resize: shift)
        case .rightArrow?: step(1, 0, resize: shift)
        case .downArrow?: step(0, -1, resize: shift)
        case .upArrow?: step(0, 1, resize: shift)
        default: break
        }
    }
    func focus(_ by: Int) {   // tab moves the selection and the keyboard to the next display's grid; not mid-drag
        guard dragging == nil, let i = grids.firstIndex(where: { $0 === self }) else { return }
        let g = grids[(i + by + grids.count) % grids.count]
        if g !== self, let src = selected, src !== g { g.start = src.start; g.end = src.end; g.claim(); g.needsDisplay = true; preview() }
        g.panel.makeKey(); g.panel.makeFirstResponder(g)
    }
    func step(_ dx: Int, _ dy: Int, resize: Bool) {
        var lo = (0, 0), hi = (cols - 1, rows - 1)   // no selection on this display yet: start from the whole of it
        if let s = selection {
            lo = (s.x.lowerBound, s.y.lowerBound); hi = (s.x.upperBound, s.y.upperBound)
            if resize {
                hi = (min(max(hi.0 + dx, lo.0), cols - 1), min(max(hi.1 + dy, lo.1), rows - 1))
            } else {
                let mx = min(max(dx, -lo.0), cols - 1 - hi.0), my = min(max(dy, -lo.1), rows - 1 - hi.1)
                lo = (lo.0 + mx, lo.1 + my); hi = (hi.0 + mx, hi.1 + my)
            }
            if !pending, lo == (s.x.lowerBound, s.y.lowerBound), hi == (s.x.upperBound, s.y.upperBound) { return }
        }
        claim(); start = lo; end = hi; pending = false; needsDisplay = true; preview()
    }

    override func draw(_ dirty: NSRect) {
        guard !grid.isEmpty else { return }   // layer-backed views get drawn at zero size before the panel is shown
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
        if let app = targetApp {   // header: the app the window belongs to, same on every display
            let icon = NSRect(x: grid.minX + 2, y: cellArea.maxY, width: headerHeight - 16, height: headerHeight - 16)
            app.icon?.draw(in: icon, from: .zero, operation: .sourceOver, fraction: 1)
            let name = NSAttributedString(string: app.localizedName ?? "", attributes: [
                .font: NSFont.systemFont(ofSize: 20, weight: .medium), .foregroundColor: NSColor.white.withAlphaComponent(0.9), .paragraphStyle: style])
            let s = name.size()
            name.draw(in: NSRect(x: icon.maxX + 12, y: icon.midY - s.height / 2, width: grid.maxX - icon.maxX - 12, height: s.height))
        }
        let cw = grid.width / CGFloat(cols), ch = grid.height / CGFloat(rows)
        // extra gap at boundary i of n: halves widest, thirds/quarters narrower, everything else uniform
        func gap(_ i: Int, _ n: Int) -> CGFloat {
            i == 0 || i == n ? 0 : (i * 2) % n == 0 ? 3 : (i * 3) % n == 0 || (i * 4) % n == 0 ? 1.5 : 0
        }
        func edge(_ c: CGFloat, _ n: Int, _ size: CGFloat, _ tol: CGFloat, _ sign: CGFloat) -> CGFloat {
            let i = c.rounded()
            return abs(c - i) <= tol ? i * size + sign * (2 + gap(Int(i), n)) : c * size
        }
        func path(_ r: NSRect, tolX: CGFloat = 0, tolY: CGFloat = 0) -> NSBezierPath {
            let x0 = grid.minX + edge(r.minX, cols, cw, tolX, 1), x1 = grid.minX + edge(r.maxX, cols, cw, tolX, -1)
            let y0 = grid.minY + edge(r.minY, rows, ch, tolY, 1), y1 = grid.minY + edge(r.maxY, rows, ch, tolY, -1)
            return NSBezierPath(roundedRect: NSRect(x: x0, y: y0, width: max(x1 - x0, 0), height: max(y1 - y0, 0)), xRadius: 4, yRadius: 4)
        }
        func rect(_ x: ClosedRange<Int>, _ y: ClosedRange<Int>) -> NSBezierPath {
            path(NSRect(x: x.lowerBound, y: y.lowerBound, width: x.count, height: y.count))
        }
        for x in 0..<cols { for y in 0..<rows {
            let p = rect(x...x, y...y)
            NSColor.white.withAlphaComponent(0.10).setFill(); p.fill()
            NSColor.white.withAlphaComponent(0.20).setStroke(); p.stroke()
        }}
        let v = screen.visibleFrame, c = CGFloat(cols), r = CGFloat(rows)
        for u in ghosts {
            let p = path(NSRect(x: u.minX * c, y: u.minY * r, width: u.width * c, height: u.height * r), tolX: 2 * c / v.width, tolY: 2 * r / v.height)
            NSColor.white.withAlphaComponent(0.25).setFill(); p.fill()
            NSColor.white.withAlphaComponent(0.45).setStroke(); p.stroke()
        }
        if let s = selection {
            let p = rect(s.x, s.y)
            NSColor.controlAccentColor.withAlphaComponent(pending ? 0.3 : 0.85).setFill(); p.fill()
            (pending ? NSColor.controlAccentColor : NSColor.white.withAlphaComponent(0.7)).setStroke(); p.lineWidth = pending ? 2 : 1.5; p.stroke()
        }
        for (i, p) in list.enumerated() {
            let r = entryRect(i), cap = NSRect(x: r.minX + 2, y: r.midY - 8, width: 16, height: 16)
            if pressed == i { NSColor.white.withAlphaComponent(0.15).setFill(); NSBezierPath(roundedRect: r, xRadius: 5, yRadius: 5).fill() }
            NSColor.white.withAlphaComponent(0.18).setFill(); NSBezierPath(roundedRect: cap, xRadius: 4, yRadius: 4).fill()
            let n = NSAttributedString(string: "\(i + 1)", attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold), .foregroundColor: NSColor.white])
            n.draw(at: NSPoint(x: cap.midX - n.size().width / 2, y: cap.midY - n.size().height / 2))
            (p.name as NSString).draw(in: NSRect(x: cap.maxX + 6, y: r.minY + 2, width: r.maxX - cap.maxX - 12, height: 15),
                                      withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.white.withAlphaComponent(0.85), .paragraphStyle: style])
        }
        if grids.count > 1, window?.isKeyWindow == true {
            let p = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 17, yRadius: 17)
            NSColor.white.withAlphaComponent(0.8).setStroke(); p.lineWidth = 2; p.stroke()
        }
    }
}

final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
    var grid: GridView? { grids.first { $0.panel === self } }
    override func becomeKey() { super.becomeKey(); grid?.needsDisplay = true }
    override func resignKey() {   // the keyboard moving to another grid panel (Tab, a click on it) keeps the grid; anywhere else dismisses
        super.resignKey()
        grid?.needsDisplay = true
        DispatchQueue.main.async { if !grids.contains(where: { $0.panel.isKeyWindow }) { cancelGrid() } }
    }
}

func makePanel(_ view: GridView) -> Panel {
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
    return panel
}

func showGrid() {
    targetWindow = recordMode ? nil : pickTarget()   // before the panels appear; record mode moves nothing
    original = targetWindow.flatMap(axFrame)
    if original == nil { targetWindow = nil }
    moved = false; dragging = nil
    let screens = NSScreen.screens, ghosts = ghostFrames(), top = NSScreen.screens[0].frame.maxY
    let list = recordMode ? [] : Array(presets.prefix(9))
    while grids.count < screens.count { grids.append(spare.popLast() ?? GridView()) }
    while grids.count > screens.count { let g = grids.removeLast(); g.clear(); g.panel.orderOut(nil); spare.append(g) }
    let frame = original.map { NSRect(x: $0.0.x, y: top - $0.0.y - $0.1.height, width: $0.1.width, height: $0.1.height) }
    let home = frame.flatMap { r in screens.first { NSMouseInRect(NSPoint(x: r.midX, y: r.midY), $0.frame, false) } }   // this display's grid outlines the window and takes the keyboard
    let keyFrame = (home ?? screenUnderCursor()).frame
    var key = grids[0]
    for (g, s) in zip(grids, screens) {
        g.screen = s; g.list = list; g.clear()
        g.ghosts = ghosts.map { screenFraction(of: $0, on: s) }.filter { !$0.isEmpty }
        if s.frame == keyFrame { key = g }
        if let r = frame, s.frame == home?.frame {
            let u = screenFraction(of: r, on: s)
            if !u.isEmpty {
                let x = cellRange(u.minX, u.maxX, cols), y = cellRange(u.minY, u.maxY, rows)
                g.start = (x.lowerBound, y.lowerBound); g.end = (x.upperBound, y.upperBound); g.pending = true
            }
        }
        let f = s.visibleFrame, w: CGFloat = 480, h = w * f.height / f.width + g.listHeight + g.headerHeight   // the grid keeps the display's aspect; the list and the header add to it
        g.panel.setFrame(NSRect(x: f.midX - w / 2, y: f.midY - h / 2, width: w, height: h), display: true)
        g.frame = g.panel.contentView!.bounds
        g.panel.alphaValue = 0
        g.panel.orderFront(nil)
    }
    gridActive = true
    key.panel.makeKeyAndOrderFront(nil)
    key.panel.makeFirstResponder(key)
    NSAnimationContext.runAnimationGroup { c in c.duration = 0.12; grids.forEach { $0.panel.animator().alphaValue = 1 } }
}
func hideGrid() {
    recordMode = false
    NSAnimationContext.runAnimationGroup({ c in c.duration = 0.10; grids.forEach { $0.panel.animator().alphaValue = 0 } }) {
        if !gridActive { grids.forEach { $0.panel.orderOut(nil) } }
    }
}
