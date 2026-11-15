import Cocoa

// A theme is JSON that styles the nine things the panel draws. Each is an object with whichever of fill, stroke, text,
// lineWidth and radius it uses; "spacing" is the space between cells. Values at the top level hold in both modes, those
// under "dark" and "light" in one, and whatever a theme leaves out comes from Default.
// Built-in themes are in BuiltinThemes.swift, the user's are .json files in themesFolder. A theme's id is its name
// (built-in) or its file name.
let themeElements = ["panel", "header", "cell", "ghost", "selection", "pending", "preset", "keycap", "focusRing"]
let styleProperties = ["fill", "stroke", "text", "lineWidth", "radius"]

struct ThemeProblem: Error { var text: String }

struct Paint: Decodable {   // "#RRGGBB", "#RRGGBBAA", "accent" or "none", then optionally a space and an opacity such as "40%"
    var fixed: NSColor?, alpha: CGFloat = 1
    var color: NSColor { fixed ?? NSColor.controlAccentColor.withAlphaComponent(alpha) }   // the accent colour is looked up when drawn
    init(from d: Decoder) throws {
        let s = try d.singleValueContainer().decode(String.self), parts = s.lowercased().split(separator: " ")
        let bad = ThemeProblem(text: d.codingPath.map(\.stringValue).joined(separator: ".") + ": “\(s)” is not a colour.")
        if parts.count == 2, parts[1].hasSuffix("%"), let a = Double(parts[1].dropLast()), (0...100).contains(a) { alpha = a / 100 }
        else if parts.count != 1 { throw bad }
        if parts[0] == "accent" { return }
        if parts[0] == "none" { fixed = .clear; return }
        let hex = parts[0].dropFirst()
        guard parts[0].hasPrefix("#"), hex.count == 6 || hex.count == 8, hex.allSatisfy(\.isHexDigit), let v = UInt32(hex, radix: 16) else { throw bad }
        let rgba = hex.count == 6 ? v << 8 | 0xFF : v
        fixed = NSColor(srgbRed: CGFloat(rgba >> 24) / 255, green: CGFloat(rgba >> 16 & 0xFF) / 255, blue: CGFloat(rgba >> 8 & 0xFF) / 255,
                        alpha: CGFloat(rgba & 0xFF) / 255 * alpha)
    }
}
struct Style: Decodable { var fill, stroke, text: Paint?; var lineWidth, radius: CGFloat? }
struct Look: Decodable {   // one mode of a theme, complete
    var panel, header, cell, ghost, selection, pending, preset, keycap, focusRing: Style
    var spacing: CGFloat
}

let themesFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GridSnap/Themes")
var userThemes: [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: themesFolder.path)) ?? []).filter { $0.hasSuffix(".json") }
        .sorted { $0.dropLast(5).localizedStandardCompare($1.dropLast(5)) == .orderedAscending }   // by name, as Finder would: "X copy" before "X copy 2"
}
func isBuiltin(_ id: String) -> Bool { builtinThemes.contains { $0.name == id } }
var themeID: String {   // the chosen theme; Default once its file is gone
    let id = defaults.string(forKey: "theme") ?? ""
    return isBuiltin(id) || userThemes.contains(id) ? id : "Default"
}
var darkMode: Bool {
    switch defaults.integer(forKey: "appearance") {
    case 1: false
    case 2: true
    default: NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

func keyProblem(_ json: [String: Any], modes: Bool = true) -> String? {   // a misspelt key would otherwise do nothing, silently
    for (k, v) in json.sorted(by: { $0.key < $1.key }) where k != "spacing" {
        guard themeElements.contains(k) || modes && (k == "dark" || k == "light") else { return "Unknown key “\(k)”." }
        guard let d = v as? [String: Any] else { return "“\(k)” must be an object in braces." }
        if !themeElements.contains(k) { if let p = keyProblem(d, modes: false) { return "In “\(k)”: \(p)" } }
        else if let bad = d.keys.sorted().first(where: { !styleProperties.contains($0) }) { return "Unknown key “\(bad)” in “\(k)”." }
    }
    return nil
}
func themeJSON(_ id: String) throws -> [String: Any] {
    let data = try builtinThemes.first { $0.name == id }.map { Data($0.json.utf8) } ?? Data(contentsOf: themesFolder.appendingPathComponent(id))
    guard let json = try JSONSerialization.jsonObject(with: data, options: .json5Allowed) as? [String: Any] else {   // JSON5: comments and trailing commas pass
        throw ThemeProblem(text: "The file must hold one object in braces.")
    }
    guard JSONSerialization.isValidJSONObject(json) else {   // JSON5 reads NaN and Infinity, and writing them back out in loadTheme would raise
        throw ThemeProblem(text: "NaN and Infinity are not numbers a theme can use.")
    }
    if let p = keyProblem(json) { throw ThemeProblem(text: p) }
    return json
}
let defaultTheme = try! themeJSON("Default")
func merged(_ a: [String: Any], _ b: [String: Any]) -> [String: Any] {
    a.merging(b) { x, y in if let x = x as? [String: Any], let y = y as? [String: Any] { merged(x, y) } else { y } }
}
func resolved(_ theme: [String: Any], dark: Bool) -> [String: Any] {   // Default, then the theme, each as its shared values under the mode's own
    func mode(_ t: [String: Any]) -> [String: Any] {
        merged(t.filter { $0.key != "dark" && $0.key != "light" }, t[dark ? "dark" : "light"] as? [String: Any] ?? [:])
    }
    return merged(mode(defaultTheme), mode(theme))
}
func loadTheme(_ id: String) throws -> (dark: Look, light: Look) {   // both modes, so a mistake shows whichever is in use
    let json = try themeJSON(id)
    func look(_ dark: Bool) throws -> Look {
        try JSONDecoder().decode(Look.self, from: JSONSerialization.data(withJSONObject: resolved(json, dark: dark)))
    }
    return try (look(true), look(false))
}
func themeProblem(_ id: String) -> String? {
    do { _ = try loadTheme(id); return nil }
    catch let p as ThemeProblem { return p.text }
    catch DecodingError.typeMismatch(_, let c), DecodingError.valueNotFound(_, let c) {
        let path = c.codingPath.map(\.stringValue), number = ["lineWidth", "radius", "spacing"].contains(path.last ?? "")
        return path.joined(separator: ".") + (number ? " must be a number." : " must be a colour in quotes.")
    }
    catch { return (error as NSError).userInfo[NSDebugDescriptionErrorKey] as? String ?? error.localizedDescription }
}
var look = try! loadTheme("Default").dark   // what the grid is drawn with; showGrid sets it

func themeText(_ id: String) throws -> String {   // every value of both modes, an element per line: the file Edit a Copy writes
    let json = try themeJSON(id)
    func mode(_ dark: Bool) -> String {
        let all = resolved(json, dark: dark)
        let lines = themeElements.map { e in
            let style = all[e] as? [String: Any] ?? [:]
            let values = styleProperties.compactMap { p in
                style[p].flatMap { v in v is NSNull ? nil : "\"\(p)\": " + ((v as? String).map { "\"\($0)\"" } ?? "\(v)") }
            }
            return "    " + "\"\(e)\":".padding(toLength: 13, withPad: " ", startingAt: 0) + "{ \(values.joined(separator: ", ")) },\n"
        }
        return "  \"\(dark ? "dark" : "light")\": {\n\(lines.joined())    \"spacing\": \(all["spacing"] ?? 4)\n  }"
    }
    return "{\n\(mode(true)),\n\(mode(false))\n}\n"
}
func copyTheme(_ id: String) throws -> String {   // writes the theme out as a new file and returns its name
    var n = 1, name = "\(id) copy.json"
    while FileManager.default.fileExists(atPath: themesFolder.appendingPathComponent(name).path) { n += 1; name = "\(id) copy \(n).json" }   // asks the disk, which may ignore case
    try FileManager.default.createDirectory(at: themesFolder, withIntermediateDirectories: true)
    try themeText(id).write(to: themesFolder.appendingPathComponent(name), atomically: true, encoding: .utf8)
    return name
}
