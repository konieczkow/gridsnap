import Cocoa
import Carbon

// grid, gap, hotkey (keyCode/keyMods/keyLabel, default ⌃⌥D), target rule and presets live in UserDefaults
let defaults: UserDefaults = {
    let d = UserDefaults.standard
    let fullScreen = Preset(name: "Full screen", x: 0, y: 0, w: 1, h: 1, keyCode: kVK_ANSI_F, keyMods: optionKey | controlKey, keyLabel: "⌃⌥F")
    d.register(defaults: ["cols": 12, "rows": 8, "gap": 0, "presets": try! JSONEncoder().encode([fullScreen])])
    return d
}()
var cols: Int { min(max(defaults.integer(forKey: "cols"), 1), 24) }
var rows: Int { min(max(defaults.integer(forKey: "rows"), 1), 24) }
