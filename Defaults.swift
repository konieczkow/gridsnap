import Cocoa

// grid, gap, hotkey (keyCode/keyMods/keyLabel, default ⌃⌥D), target rule and presets live in UserDefaults
let defaults: UserDefaults = {
    let d = UserDefaults.standard
    d.register(defaults: ["cols": 12, "rows": 8, "gap": 0])
    return d
}()
var cols: Int { min(max(defaults.integer(forKey: "cols"), 1), 24) }
var rows: Int { min(max(defaults.integer(forKey: "rows"), 1), 24) }
