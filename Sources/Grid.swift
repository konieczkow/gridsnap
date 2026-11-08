import Cocoa

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
    var selectionFraction: NSRect? {
        guard let s = selection else { return nil }
        return NSRect(x: Double(s.x.lowerBound) / Double(cols), y: Double(s.y.lowerBound) / Double(rows),
                      width: Double(s.x.count) / Double(cols), height: Double(s.y.count) / Double(rows))
    }
    var selectionFrame: NSRect? { selectionFraction.map { screenFrame(fraction: $0, on: screen) } }

    var ghosts: [NSRect] = []
    func clear() { start = nil; end = nil; pending = false; needsDisplay = true }
    func claim() { for g in grids where g !== self { g.clear() } }   // a selection here drops any on another display

    override func mouseDown(with e: NSEvent) {
        guard gridActive else { return }
        dragging = self; claim(); start = cell(e); end = start; pending = false; needsDisplay = true   // no preview yet: one cell is a tiny window, wait for the drag
    }
    func track(_ e: NSEvent) {   // cursor outside the panel = no selection, so releasing there cancels
        guard gridActive else { return }
        let new = bounds.contains(convert(e.locationInWindow, from: nil)) ? cell(e) : nil
        guard new?.0 != end?.0 || new?.1 != end?.1 else { return }   // only hit AX when the cell changes
        end = new; needsDisplay = true; preview()
    }
    override func mouseDragged(with e: NSEvent) { track(e) }
    override func mouseUp(with e: NSEvent) { dragging = nil; track(e); commitGrid(save: e.modifierFlags.contains(.shift)) }
    override func keyDown(with e: NSEvent) {
        guard gridActive else { return }
        if e.keyCode == 53 { cancelGrid(); return }   // esc, also mid-drag
        let shift = e.modifierFlags.contains(.shift)
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
    while grids.count < screens.count { grids.append(spare.popLast() ?? GridView()) }
    while grids.count > screens.count { let g = grids.removeLast(); g.clear(); g.panel.orderOut(nil); spare.append(g) }
    let frame = original.map { NSRect(x: $0.0.x, y: top - $0.0.y - $0.1.height, width: $0.1.width, height: $0.1.height) }
    let home = frame.flatMap { r in screens.first { NSMouseInRect(NSPoint(x: r.midX, y: r.midY), $0.frame, false) } }   // this display's grid outlines the window and takes the keyboard
    let keyFrame = (home ?? screenUnderCursor()).frame
    var key = grids[0]
    for (g, s) in zip(grids, screens) {
        g.screen = s; g.clear()
        g.ghosts = ghosts.map { screenFraction(of: $0, on: s) }.filter { !$0.isEmpty }
        if s.frame == keyFrame { key = g }
        if let r = frame, s.frame == home?.frame {
            let u = screenFraction(of: r, on: s)
            if !u.isEmpty {
                let x = cellRange(u.minX, u.maxX, cols), y = cellRange(u.minY, u.maxY, rows)
                g.start = (x.lowerBound, y.lowerBound); g.end = (x.upperBound, y.upperBound); g.pending = true
            }
        }
        let f = s.visibleFrame, w: CGFloat = 480, h = w * f.height / f.width
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
