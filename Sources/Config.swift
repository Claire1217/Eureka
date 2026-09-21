import Cocoa
import Carbon

let HOTKEY_KEYCODE: UInt32 = 17          // 'T' key
let HOTKEY_SCREENSHOT: UInt32 = 15       // 'R' key
let HOTKEY_MODIFIERS: UInt32 = UInt32(optionKey)  // Option (⌥)

struct HotkeyCombination: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
}

struct HotkeyPair: Equatable {
    let capture: HotkeyCombination
    let screenshot: HotkeyCombination
}

private let keyCodeNames: [UInt32: String] = [
    0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",
    11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",
    20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"-",28:"8",
    29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",36:"Return",37:"L",
    38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",
    47:".",48:"Tab",49:"Space",50:"`"
]

var onKeyboardLayoutChanged: (() -> Void)?

private let keyboardLayoutObserver: Void = {
    DistributedNotificationCenter.default().addObserver(
        forName: NSNotification.Name(rawValue: kTISNotifySelectedKeyboardInputSourceChanged as String),
        object: nil, queue: .main
    ) { _ in onKeyboardLayoutChanged?() }
}()

func hotkeyKeyName(_ keyCode: UInt32) -> String? {
    _ = keyboardLayoutObserver
    if let fixed = [UInt32(36): "Return", 48: "Tab", 49: "Space"][keyCode] { return fixed }
    let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
    if let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        if let bytes = CFDataGetBytePtr(data) {
            let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKeyState: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                &deadKeyState, characters.count, &length, &characters)
            if status == noErr && length > 0 {
                let translated = String(utf16CodeUnits: characters, count: length).uppercased()
                if !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return translated
                }
            }
        }
    }
    return keyCodeNames[keyCode]
}

func hotkeyDisplayName(_ hotkey: HotkeyCombination) -> String {
    var symbols = ""
    if hotkey.modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
    if hotkey.modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
    if hotkey.modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
    if hotkey.modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
    return symbols + (hotkeyKeyName(hotkey.keyCode) ?? "Unsupported key (\(hotkey.keyCode))")
}

func hotkeyLabel(_ keyDefault: String, _ modDefault: String, fallbackKey: UInt32, fallbackMod: UInt32) -> String {
    let code = UserDefaults.standard.object(forKey: keyDefault) as? UInt32 ?? fallbackKey
    let mods = UserDefaults.standard.object(forKey: modDefault) as? UInt32 ?? fallbackMod
    return hotkeyDisplayName(HotkeyCombination(keyCode: code, modifiers: mods))
}

var captureHotkeyLabel: String {
    hotkeyLabel("hotkeyCapture", "hotkeyCaptureMods", fallbackKey: HOTKEY_KEYCODE, fallbackMod: HOTKEY_MODIFIERS)
}

var screenshotHotkeyLabel: String {
    hotkeyLabel("hotkeyScreenshot", "hotkeyScreenshotMods", fallbackKey: HOTKEY_SCREENSHOT, fallbackMod: HOTKEY_MODIFIERS)
}

/// The few strings the panel shows are Chinese on a Chinese system and English everywhere else.
let prefersChinese: Bool = (Locale.preferredLanguages.first ?? "en").hasPrefix("zh")
func L(_ zh: String, _ en: String) -> String { prefersChinese ? zh : en }

let THOUGHT_COLORS = ["coral", "blue", "purple", "green", "amber", "olive", "pink", "steel"]

struct EU {
    static let green  = NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1)
    static let red    = NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)
    static let primary = NSColor(white: 0.06, alpha: 1)
    static let text    = NSColor(white: 0.13, alpha: 1)
    static let body    = NSColor(white: 0.24, alpha: 1)
    static let sub     = NSColor(white: 0.40, alpha: 1)
    static let muted   = NSColor(white: 0.55, alpha: 1)
    static let faint   = NSColor(white: 0.72, alpha: 1)
    static let rule    = NSColor(white: 0, alpha: 0.07)
    static let ctxBg   = NSColor(white: 0, alpha: 0.035)
}
