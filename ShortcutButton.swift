import Cocoa
import Carbon

// a button that records the next key combo when clicked
final class ShortcutButton: NSButton {
    var combo: (code: Int, mods: Int, label: String)? { didSet { refresh() } }
    var onChange: (() -> Void)?
    private var monitor: Any?
    func refresh() { title = combo?.label ?? "Click to set" }

    static func make(_ combo: (code: Int, mods: Int, label: String)?, onChange: @escaping () -> Void = {}) -> ShortcutButton {
        let b = ShortcutButton(title: "", target: nil, action: nil)
        b.target = b; b.action = #selector(startRecording); b.combo = combo; b.onChange = onChange
        return b
    }
    static func combo(from e: NSEvent) -> (code: Int, mods: Int, label: String)? {
        let f = e.modifierFlags.intersection([.command, .option, .control, .shift])
        guard e.keyCode != 53, !f.isEmpty else { return nil }   // esc or a bare key keeps the old shortcut
        var mods = 0, label = ""
        for (flag, mod, sym) in [(NSEvent.ModifierFlags.control, controlKey, "⌃"), (.option, optionKey, "⌥"),
                                 (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")] where f.contains(flag) { mods |= mod; label += sym }
        return (Int(e.keyCode), mods, label + (e.charactersIgnoringModifiers?.uppercased() ?? "?"))
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
