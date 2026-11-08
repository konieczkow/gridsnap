import Cocoa
import Carbon

// a button that records the next key combo when clicked
final class ShortcutButton: NSButton {
    var combo: (code: Int, mods: Int, label: String)? { didSet { refresh() } }
    var onChange: (() -> Void)?
    private var monitor: Any?
    static let keyNames: [Int: String] = {
        var n = [kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Space: "Space", kVK_Return: "↩",
                 kVK_ANSI_KeypadEnter: "⌤", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Home: "↖", kVK_End: "↘",
                 kVK_PageUp: "⇞", kVK_PageDown: "⇟"]
        for (i, k) in [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
                       kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20].enumerated() { n[k] = "F\(i + 1)" }
        return n
    }()
    static func symbols(_ mods: Int) -> String {
        [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")].filter { mods & $0.0 != 0 }.map { $0.1 }.joined()
    }
    static func display(_ c: (code: Int, mods: Int, label: String)) -> String {
        keyNames[c.code].map { symbols(c.mods) + $0 } ?? c.label
    }
    func refresh() { title = combo.map(Self.display) ?? "Click to set" }

    static func make(_ combo: (code: Int, mods: Int, label: String)?, onChange: @escaping () -> Void = {}) -> ShortcutButton {
        let b = ShortcutButton(title: "", target: nil, action: nil)
        b.target = b; b.action = #selector(startRecording); b.combo = combo; b.onChange = onChange
        return b
    }
    static func combo(from e: NSEvent) -> (code: Int, mods: Int, label: String)? {
        let f = e.modifierFlags.intersection([.command, .option, .control, .shift])
        guard e.keyCode != 53, !f.isEmpty else { return nil }   // esc or a bare key keeps the old shortcut
        var mods = 0
        for (flag, mod) in [(NSEvent.ModifierFlags.control, controlKey), (.option, optionKey), (.shift, shiftKey), (.command, cmdKey)] where f.contains(flag) { mods |= mod }
        return (Int(e.keyCode), mods, symbols(mods) + (e.charactersIgnoringModifiers?.uppercased() ?? "?"))
    }
    static weak var active: ShortcutButton?   // only one recorder listens at a time
    func cancelRecording() {   // safe to call when not recording; always leaves hotkeys registered
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil; refresh(); registerAll() }
    }
    @objc func startRecording() {
        guard monitor == nil else { return }
        Self.active?.cancelRecording(); Self.active = self
        title = "Type shortcut…"; unregisterAll()   // so existing combos reach us instead of firing
        // a local monitor swallows the key before alert/window buttons can claim esc, return or ⌘-keys
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self else { return e }
            if let m = self.monitor { NSEvent.removeMonitor(m); self.monitor = nil }
            if let c = Self.combo(from: e) { self.combo = c; self.onChange?() } else { self.refresh() }
            registerAll()
            return nil
        }
    }
    deinit { if let m = monitor { NSEvent.removeMonitor(m); registerAll() } }   // table rows get rebuilt mid-recording
}
