import Cocoa
import Carbon

// ids: 1 grid, 2 undo, 100+i preset i
let hotKeySig: OSType = 0x4753_4E50
var hotKeyRefs: [EventHotKeyRef] = []
func unregisterAll() { hotKeyRefs.forEach { UnregisterEventHotKey($0) }; hotKeyRefs = [] }
func registerAll() {
    unregisterAll()
    func reg(_ code: Int, _ mods: Int, _ id: UInt32) {
        var r: EventHotKeyRef?
        if RegisterEventHotKey(UInt32(code), UInt32(mods), EventHotKeyID(signature: hotKeySig, id: id), GetApplicationEventTarget(), 0, &r) == noErr,
           let r = r { hotKeyRefs.append(r) }
    }
    reg(mainCombo.code, mainCombo.mods, 1)
    reg(undoCombo.code, undoCombo.mods, 2)
    for (i, p) in presets.enumerated() { reg(p.keyCode, p.keyMods, UInt32(100 + i)) }
}
func installHotKeyHandler() {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
        var id = EventHotKeyID()
        GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
        let i = Int(id.id) - 100
        if i >= 0 { if i < presets.count { applyPreset(presets[i]) } }
        else if id.id == 2 { undoSnap() }
        else if panel.isVisible { hideGrid() } else { showGrid() }
        return noErr
    }, 1, &spec, nil, nil)
    registerAll()
}
