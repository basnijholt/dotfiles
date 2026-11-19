// app-hotkeys: global hotkeys that bring an app to the front, read from a plain text file.
// Copies Keyboard Maestro's "Activate a Specific Application": a Carbon RegisterEventHotKey
// handler calls SetFrontProcessWithOptions. No event tap, so no Accessibility permission.
//   app-hotkeys [config]            run resident (default ~/.config/app-hotkeys/hotkeys.conf)
//   app-hotkeys --check [config]    parse, print the bindings, exit 1 on errors
//   app-hotkeys --activate <app>    run the activation path once (bundle id or .app path)
import AppKit
import Carbon

// Deprecated since 10.9 and hidden from Swift, but still declared in HIServices/Processes.h and
// exported. They raise an app with no cooperative-activation handshake, which is why KM uses them.
@_silgen_name("GetProcessForPID")
func getProcessForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
@_silgen_name("SetFrontProcessWithOptions")
func setFrontProcessWithOptions(_ psn: UnsafePointer<ProcessSerialNumber>, _ options: OptionBits) -> OSStatus

struct Binding: Equatable {
    let line: Int, mods: UInt32, key: UInt32, combo: String, target: String
}

// US ANSI virtual key codes (kVK_*). Codes 0...50 in order; "" marks the ISO-only § key (10).
var keyCodes: [String: UInt32] = {
    let ansi = ["a", "s", "d", "f", "h", "g", "z", "x", "c", "v", "", "b", "q", "w", "e", "r", "y", "t",
                "1", "2", "3", "4", "6", "5", "=", "9", "7", "-", "8", "0", "]", "o", "u", "[", "i", "p",
                "return", "l", "j", "'", "k", ";", "\\", ",", "/", "n", "m", ".", "tab", "space", "`"]
    var map = [String: UInt32]()
    for (code, name) in ansi.enumerated() where !name.isEmpty { map[name] = UInt32(code) }
    let fkeys: [UInt32] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
    for (i, code) in fkeys.enumerated() { map["f\(i + 1)"] = code }
    let named: [String: UInt32] = [
        "enter": 36, "delete": 51, "backspace": 51, "escape": 53, "esc": 53, "forwarddelete": 117,
        "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
        "left": 123, "right": 124, "down": 125, "up": 126, "minus": 27, "equal": 24,
        "leftbracket": 33, "rightbracket": 30, "quote": 39, "semicolon": 41, "backslash": 42,
        "comma": 43, "slash": 44, "period": 47, "grave": 50,
    ]
    return map.merging(named) { a, _ in a }
}()
let modifierBits: [String: UInt32] = [
    "ctrl": UInt32(controlKey), "control": UInt32(controlKey), "alt": UInt32(optionKey),
    "opt": UInt32(optionKey), "option": UInt32(optionKey), "shift": UInt32(shiftKey),
    "cmd": UInt32(cmdKey), "command": UInt32(cmdKey),
    "hyper": UInt32(controlKey | optionKey | shiftKey | cmdKey),
]

func comboName(_ mods: UInt32, _ key: String) -> String {
    let names: [(Int, String)] = [(controlKey, "ctrl"), (optionKey, "alt"), (shiftKey, "shift"), (cmdKey, "cmd")]
    return (names.filter { mods & UInt32($0.0) != 0 }.map(\.1) + [key]).joined(separator: "+")
}

func parse(_ text: String) -> (bindings: [Binding], errors: [String]) {
    var bindings = [Binding](), errors = [String](), seen = [String: Int]()
    for (i, raw) in text.components(separatedBy: "\n").enumerated() {
        let n = i + 1
        let line = String(raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0])
            .trimmingCharacters(in: .whitespaces)
        if line.isEmpty { continue }
        guard let eq = line.lastIndex(of: "=") else {
            errors.append("line \(n): expected 'modifiers+key = bundle.id', got '\(line)'"); continue
        }
        let lhs = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
        let target = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        if lhs.isEmpty || target.isEmpty {
            errors.append("line \(n): expected 'modifiers+key = bundle.id', got '\(line)'"); continue
        }
        let parts = lhs.split(separator: "+", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        var mods: UInt32 = 0, ok = true
        for m in parts.dropLast() {
            guard let bit = modifierBits[m] else {
                errors.append("line \(n): unknown modifier '\(m)' (use ctrl, alt, shift, cmd, hyper)")
                ok = false; break
            }
            mods |= bit
        }
        guard ok else { continue }
        let keyName = parts.last!
        guard let key = keyCodes[keyName] else {
            errors.append("line \(n): " + (keyName.isEmpty ? "missing key after '+'" : "unknown key '\(keyName)'")); continue
        }
        let combo = comboName(mods, keyName)
        if let first = seen[combo] {
            errors.append("line \(n): \(combo) is already bound on line \(first)"); continue
        }
        seen[combo] = n
        bindings.append(Binding(line: n, mods: mods, key: key, combo: combo, target: target))
    }
    return (bindings, errors)
}

func log(_ message: String) {
    let ts = Date().formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current))
    FileHandle.standardError.write("\(ts) \(message)\n".data(using: .utf8)!)
}

// MARK: Activation

func isPath(_ target: String) -> Bool { target.contains("/") || target.hasSuffix(".app") }

func appURL(_ target: String) -> URL? {
    if isPath(target) {
        let url = URL(fileURLWithPath: (target as NSString).expandingTildeInPath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    return NSWorkspace.shared.urlForApplication(withBundleIdentifier: target)
}

func runningApp(_ target: String) -> NSRunningApplication? {
    if !isPath(target) {
        return NSRunningApplication.runningApplications(withBundleIdentifier: target).first { !$0.isTerminated }
    }
    let path = appURL(target)?.resolvingSymlinksInPath().path
    return NSWorkspace.shared.runningApplications.first { $0.bundleURL?.resolvingSymlinksInPath().path == path }
}

func setFront(_ pid: pid_t) -> OSStatus {
    var psn = ProcessSerialNumber()
    let err = getProcessForPID(pid, &psn)
    return err != noErr ? err : setFrontProcessWithOptions(&psn, 0)  // 0 = all windows, like KM
}

func hasWindows(_ pid: pid_t) -> Bool {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    return (list as? [[String: Any]] ?? []).contains {
        $0[kCGWindowOwnerPID as String] as? pid_t == pid && $0[kCGWindowLayer as String] as? Int == 0
            && ($0[kCGWindowAlpha as String] as? Double ?? 1) > 0
    }
}

// What a Dock click sends: the app opens (or unminimizes) a window if it shows none.
func reopen(_ pid: pid_t) -> OSStatus {
    let event = NSAppleEventDescriptor(
        eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEReopenApplication),
        targetDescriptor: NSAppleEventDescriptor(processIdentifier: pid),
        returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
    return OSStatus(AESendMessage(event.aeDesc, nil, AESendMode(kAENoReply), kAEDefaultTimeout))
}

func activate(_ target: String, done: @escaping (Bool) -> Void) {
    let start = DispatchTime.now()
    let ms = { String(format: "%.1f ms", Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6) }
    if let app = runningApp(target) {
        let pid = app.processIdentifier, wasHidden = app.isHidden  // SetFront unhides its windows
        var action = "already front"
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != pid {
            let err = setFront(pid)
            action = err == noErr ? "front" : "SetFrontProcessWithOptions failed (\(err))"
        }
        if !wasHidden && !hasWindows(pid) {
            let err = reopen(pid)
            action += err == noErr ? ", reopened" : ", reopen failed (\(err))"
        }
        log("\(target) (pid \(pid)): \(action) in \(ms())")
        return done(!action.contains("failed"))
    }
    guard let url = appURL(target) else { log("\(target): not installed"); return done(false) }
    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { app, error in
        DispatchQueue.main.async {
            guard let app else { log("\(target): launch failed: \(error?.localizedDescription ?? "?")"); return done(false) }
            let err = setFront(app.processIdentifier)
            log("\(target) (pid \(app.processIdentifier)): launched\(err == noErr ? "" : ", SetFront failed (\(err))") in \(ms())")
            done(err == noErr)
        }
    }
}

// MARK: Resident

let args = Array(CommandLine.arguments.dropFirst())
let defaultConfig = NSHomeDirectory() + "/.config/app-hotkeys/hotkeys.conf"

if args.first == "--check" {
    let path = args.count > 1 ? args[1] : defaultConfig
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { log("cannot read \(path)"); exit(1) }
    let (bindings, errors) = parse(text)
    for b in bindings {
        print("line \(b.line): \(b.combo) = \(b.target)\(appURL(b.target) == nil ? "  (not installed here)" : "")")
    }
    for e in errors { log("\(path): \(e)") }
    exit(errors.isEmpty ? 0 : 1)
}
if args.first == "--activate" {
    guard args.count == 2 else { log("usage: app-hotkeys --activate <bundle-id|path.app>"); exit(2) }
    activate(args[1]) { ok in exit(ok ? 0 : 1) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 15) { log("timed out"); exit(1) }
    RunLoop.main.run()
}
if let a = args.first, a.hasPrefix("-") || args.count > 1 {
    log("usage: app-hotkeys [config] | --check [config] | --activate <bundle-id|path.app>"); exit(2)
}

let configPath = args.first ?? defaultConfig
var bindings = [Binding](), hotKeyRefs = [EventHotKeyRef](), lastText: String?
var watchers = [DispatchSourceFileSystemObject](), reloadPending = false

func reload(force: Bool = false) {
    guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else {
        log("cannot read \(configPath); keeping \(bindings.count) bindings"); return
    }
    if text == lastText && !force { return }
    lastText = text
    let (parsed, errors) = parse(text)
    if !errors.isEmpty {
        for e in errors { log("\(configPath): \(e)") }
        log("config has errors; keeping the previous \(bindings.count) bindings"); return
    }
    hotKeyRefs.forEach { UnregisterEventHotKey($0) }
    hotKeyRefs = []
    bindings = parsed
    var failed = 0
    for (i, b) in bindings.enumerated() {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4150_484B), id: UInt32(i))  // 'APHK'
        let err = RegisterEventHotKey(b.key, b.mods, id, GetEventDispatcherTarget(), 0, &ref)
        if err == noErr, let ref { hotKeyRefs.append(ref); continue }
        failed += 1
        let why = err == eventHotKeyExistsErr ? " (eventHotKeyExistsErr: another app, e.g. Keyboard Maestro, holds it)" : ""
        log("line \(b.line): \(b.combo) = \(b.target): RegisterEventHotKey failed, OSStatus \(err)\(why)")
    }
    log("loaded \(bindings.count - failed)/\(bindings.count) bindings from \(configPath)")
}

// Watch the file and its directory (and the symlink target's), since editors and dotbot replace
// files. Re-arm after every change so a replaced file or retargeted symlink is picked up.
func watch() {
    watchers.forEach { $0.cancel() }
    let real = URL(fileURLWithPath: configPath).resolvingSymlinksInPath().path
    let dirs = Set([configPath, real].map { ($0 as NSString).deletingLastPathComponent })
    watchers = ([real] + dirs).compactMap { path in
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .delete, .rename, .extend, .attrib, .link], queue: .main)
        source.setEventHandler {
            guard !reloadPending else { return }
            reloadPending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { reloadPending = false; reload(); watch() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }
}

NSApplication.shared.setActivationPolicy(.prohibited)
var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
    var id = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                      nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    if Int(id.id) < bindings.count {
        let b = bindings[Int(id.id)]
        log("\(b.combo) pressed")
        activate(b.target) { _ in }
    }
    return noErr
}, 1, &pressed, nil, nil)

signal(SIGHUP, SIG_IGN)
let hup = DispatchSource.makeSignalSource(signal: SIGHUP, queue: .main)
hup.setEventHandler { log("SIGHUP: reloading"); reload(force: true); watch() }
hup.resume()
reload()
watch()
NSApplication.shared.run()
