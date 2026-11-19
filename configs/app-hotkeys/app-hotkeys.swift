// app-hotkeys: global hotkeys that bring an app to the front, read from a plain text file.
// Copies Keyboard Maestro's "Activate a Specific Application": a Carbon RegisterEventHotKey
// handler calls SetFrontProcessWithOptions. No event tap, so no Accessibility permission.
//   app-hotkeys [config]            run resident (default ~/.config/app-hotkeys/hotkeys.conf)
//   app-hotkeys --check [config]    parse, print the bindings, exit 1 on errors
//   app-hotkeys --activate <app>    run the activation path once (bundle id, or a path with a /)
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
    var chord: UInt64 { UInt64(mods) << 32 | UInt64(key) }  // esc and escape are the same chord
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
    var bindings = [Binding](), errors = [String](), seen = [UInt64: Binding]()
    for (i, raw) in text.components(separatedBy: "\n").enumerated() {
        let n = i + 1
        let line = String(raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0])
            .trimmingCharacters(in: .whitespaces)
        if line.isEmpty { continue }
        let eq = line.lastIndex(of: "=")  // last, so "cmd+= = x" binds the = key
        let lhs = eq.map { line[..<$0].trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
        let target = eq.map { line[line.index(after: $0)...].trimmingCharacters(in: .whitespaces) } ?? ""
        if lhs.isEmpty || target.isEmpty {
            errors.append("line \(n): expected 'modifiers+key = bundle.id', got '\(line)'"); continue
        }
        let parts = lhs.split(separator: "+", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        if let bad = parts.dropLast().first(where: { modifierBits[$0] == nil }) {
            errors.append("line \(n): unknown modifier '\(bad)' (use ctrl, alt, shift, cmd, hyper)"); continue
        }
        let mods = parts.dropLast().reduce(UInt32(0)) { $0 | modifierBits[$1]! }, keyName = parts.last!
        guard let key = keyCodes[keyName] else {
            errors.append("line \(n): " + (keyName.isEmpty ? "missing key after '+'" : "unknown key '\(keyName)'")); continue
        }
        let b = Binding(line: n, mods: mods, key: key, combo: comboName(mods, keyName), target: target)
        if let first = seen[b.chord] {
            errors.append("line \(n): \(b.combo) is the same chord as line \(first.line) (\(first.combo))"); continue
        }
        seen[b.chord] = b
        bindings.append(b)
    }
    return (bindings, errors)
}

func log(_ message: String) {
    let ts = Date().formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current))
    FileHandle.standardError.write("\(ts) \(message)\n".data(using: .utf8)!)
}

// MARK: Activation

// Only a value with a slash is a path (./Foo.app); chat.mindroom.app is a bundle id.
func isPath(_ target: String) -> Bool { target.contains("/") }

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
    guard let path = appURL(target)?.resolvingSymlinksInPath().path else { return nil }
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

var activationRequest = 0  // a slow launch must not take the front back from a later hotkey

func activate(_ target: String, done: @escaping (Bool) -> Void) {
    activationRequest += 1
    let start = DispatchTime.now(), request = activationRequest
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
    let config = NSWorkspace.OpenConfiguration()
    config.activates = false  // we raise it below, unless a newer hotkey fired meanwhile
    NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
        DispatchQueue.main.async {
            guard let app else { log("\(target): launch failed: \(error?.localizedDescription ?? "?")"); return done(false) }
            if request != activationRequest {
                log("\(target) (pid \(app.processIdentifier)): launched, not raised (a newer hotkey fired)"); return done(true)
            }
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
let signature = OSType(0x4150_484B)  // 'APHK'
var active = [UInt32: Binding](), nextID: UInt32 = 0, lastText: String?
var registered = [UInt64: (id: UInt32, ref: EventHotKeyRef)]()  // by chord
var watchers = [String: DispatchSourceFileSystemObject](), reloadPending = false, unreadable = false

func reload(force: Bool = false) {
    guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else {
        if !unreadable { log("cannot read \(configPath); keeping \(active.count) bindings") }
        unreadable = true; return
    }
    unreadable = false
    if text == lastText && !force { return }
    lastText = text
    let (parsed, errors) = parse(text)
    if !errors.isEmpty {
        for e in errors { log("\(configPath): \(e)") }
        log("config has errors; keeping the previous \(active.count) bindings"); return
    }
    // Unchanged chords keep their registration (this process can't hold a chord twice:
    // eventHotKeyExistsErr). New chords get fresh IDs and are registered before anything is dropped,
    // so a failure leaves the working set alone, and a queued press of a removed chord finds no ID.
    var added = [UInt64: (id: UInt32, ref: EventHotKeyRef)](), staged = [UInt32: Binding]()
    for b in parsed {
        if let kept = registered[b.chord] { staged[kept.id] = b; continue }
        nextID += 1
        var ref: EventHotKeyRef?
        let err = RegisterEventHotKey(b.key, b.mods, EventHotKeyID(signature: signature, id: nextID),
                                      GetEventDispatcherTarget(), 0, &ref)
        guard err == noErr, let ref else {
            log("line \(b.line): \(b.combo) = \(b.target): RegisterEventHotKey failed, OSStatus \(err); keeping the previous \(active.count) bindings")
            added.values.forEach { UnregisterEventHotKey($0.ref) }
            return  // retried on the next edit or SIGHUP, not on every poll
        }
        added[b.chord] = (nextID, ref)
        staged[nextID] = b
    }
    let keep = Set(parsed.map(\.chord))
    for (chord, r) in registered where !keep.contains(chord) { UnregisterEventHotKey(r.ref); registered[chord] = nil }
    registered.merge(added) { $1 }
    active = staged
    log("loaded \(active.count) bindings from \(configPath)")
}

// Watch the file and its directory (and the symlink target's), since editors and dotbot replace
// files. Always arm before reading, so a change after the read fires an event. Directory watches
// live on; the file watch is renewed each time (a replaced file is a new inode). The watches only
// make reloads instant: a 2 s poll below catches whatever they miss (a missing directory, a swap
// mid-setup, a retargeted directory symlink).
func watch() {
    let real = URL(fileURLWithPath: configPath).resolvingSymlinksInPath().path
    let dirs = Set([configPath, real].map { ($0 as NSString).deletingLastPathComponent })
    for (path, source) in watchers where !dirs.contains(path) { source.cancel(); watchers[path] = nil }
    for path in [real] + dirs where watchers[path] == nil {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { continue }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .delete, .rename, .extend, .attrib, .link], queue: .main)
        source.setEventHandler {
            if !source.data.isDisjoint(with: [.delete, .rename]) { source.cancel(); watchers[path] = nil }
            guard !reloadPending else { return }
            reloadPending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { reloadPending = false; watch(); reload() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watchers[path] = source
    }
}

NSApplication.shared.setActivationPolicy(.prohibited)
var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
let installed = InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
    var id = EventHotKeyID()
    let err = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard err == noErr, id.signature == signature, let b = active[id.id] else { return OSStatus(eventNotHandledErr) }
    log("\(b.combo) pressed")
    activate(b.target) { _ in }
    return noErr
}, 1, &pressed, nil, nil)
guard installed == noErr else { log("InstallEventHandler failed, OSStatus \(installed)"); exit(1) }

signal(SIGHUP, SIG_IGN)
let hup = DispatchSource.makeSignalSource(signal: SIGHUP, queue: .main)
hup.setEventHandler {
    log("SIGHUP: reloading")
    watchers.values.forEach { $0.cancel() }; watchers = [:]  // reopen every path, in case one was retargeted
    watch(); reload(force: true)
}
hup.resume()
// reload() is a no-op while the text is unchanged, so this costs one small read every 2 s
Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in watch(); reload() }
watch()
reload()
NSApplication.shared.run()
