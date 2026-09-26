import AppKit
import ApplicationServices

struct Tab: Codable, Equatable {
    let id: Int
    let index: Int
    let active: Bool
}
struct Snapshot: Codable {
    let title: String
    let updated: Double
    let tabs: [Tab]
}
struct Reply: Codable {
    let title: String
    let updated: Double
    let tab_id: Int?
}

let stateDirectory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/state/dotfiles/wezterm-floating-tabs")
let lavender = NSColor(srgbRed: 196/255, green: 167/255, blue: 231/255, alpha: 1)
let dark = NSColor(srgbRed: 25/255, green: 23/255, blue: 36/255, alpha: 1)
let muted = NSColor(srgbRed: 57/255, green: 53/255, blue: 82/255, alpha: 1)

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}
func windowFrame(_ window: AXUIElement) -> CGRect? {
    guard let position = attribute(window, kAXPositionAttribute),
          let size = attribute(window, kAXSizeAttribute),
          CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
    else { return nil }
    var origin = CGPoint.zero
    var dimensions = CGSize.zero
    guard AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &origin),
          AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &dimensions)
    else { return nil }
    let desktopTop = NSScreen.screens.first?.frame.maxY ?? 0
    return CGRect(x: origin.x, y: desktopTop - origin.y - dimensions.height,
                  width: dimensions.width, height: dimensions.height)
}

// Keep badges centered on the window edge, but fall back to native tabs when
// fullscreen or the menu bar leaves no room for an external strip.
func placement(frame: CGRect, visible: CGRect, tabWidth: CGFloat) -> (CGRect, CGRect?)? {
    let height: CGFloat = 24
    let y = frame.maxY - height / 2
    guard y + height <= visible.maxY, frame.width >= 48 else { return nil }
    let tabs = CGRect(x: frame.minX + 6, y: y, width: min(tabWidth, frame.width - 12), height: height)
    let clock = CGRect(x: frame.midX - 49, y: y, width: 98, height: height)
    return (tabs, tabs.maxX + 12 < clock.minX ? clock : nil)
}

final class Badge: NSButton {
    var actionHandler: (() -> Void)?
    init(label: String, active: Bool, action: (() -> Void)? = nil) {
        super.init(frame: .zero)
        title = label
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = (active ? lavender : muted).cgColor
        font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        contentTintColor = active ? dark : NSColor(srgbRed: 224/255, green: 222/255, blue: 244/255, alpha: 1)
        actionHandler = action
        target = self
        self.action = #selector(invoke)
        setAccessibilityLabel(action == nil ? "Current time: \(label)" : "WezTerm tab \(label)")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    @objc func invoke() { actionHandler?() }
}

final class OverlayPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        isReleasedWhenClosed = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

func watchDirectory(_ directory: URL, onChange: @escaping () -> Void) -> DispatchSourceFileSystemObject? {
    let descriptor = open(directory.path, O_EVTONLY)
    guard descriptor >= 0 else { return nil }
    let watcher = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: descriptor, eventMask: .write, queue: .main)
    watcher.setEventHandler(handler: onChange)
    watcher.setCancelHandler { close(descriptor) }
    watcher.resume()
    return watcher
}

final class Companion: NSObject, NSApplicationDelegate {
    let tabsPanel = OverlayPanel()
    let clockPanel = OverlayPanel()
    var timer: Timer?
    var stateWatcher: DispatchSourceFileSystemObject?
    var observer: AXObserver?
    var observedWindow: AXUIElement?
    var observedPID: pid_t = 0
    var currentTabs: [Tab] = []
    var currentTitle = ""
    var currentTime = ""
    var lastHeartbeat: TimeInterval = 0
    var heartbeatTitle = ""
    let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        // Watch the directory: atomic snapshot replacement changes the inode,
        // so watching current.json itself would lose subsequent updates.
        stateWatcher = watchDirectory(stateDirectory) { [weak self] in self?.refresh() }
        // Retain a slow timer for the clock, heartbeat and stale-helper recovery.
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) { hide() }

    func write(_ reply: Reply, name: String) {
        guard let data = try? JSONEncoder().encode(reply) else { return }
        try? data.write(to: stateDirectory.appendingPathComponent(name), options: .atomic)
    }

    func hide() {
        tabsPanel.orderOut(nil)
        clockPanel.orderOut(nil)
        if !heartbeatTitle.isEmpty {
            try? FileManager.default.removeItem(at: stateDirectory.appendingPathComponent("ready.json"))
            heartbeatTitle = ""
        }
    }

    func observe(pid: pid_t, window: AXUIElement) {
        if observedPID == pid, let existing = observedWindow, CFEqual(existing, window) { return }
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observedPID = pid
        observedWindow = window
        var newObserver: AXObserver?
        let callback: AXObserverCallback = { _, _, _, context in
            guard let context else { return }
            Unmanaged<Companion>.fromOpaque(context).takeUnretainedValue().refresh()
        }
        guard AXObserverCreate(pid, callback, &newObserver) == .success, let newObserver else { return }
        observer = newObserver
        for name in [kAXMovedNotification, kAXResizedNotification, kAXUIElementDestroyedNotification,
                     kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification] {
            _ = AXObserverAddNotification(newObserver, window, name as CFString, Unmanaged.passUnretained(self).toOpaque())
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
    }

    @objc func refresh() {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == "org.wezfurlong.wezterm" || app.bundleIdentifier == "com.github.wez.wezterm",
              let data = try? Data(contentsOf: stateDirectory.appendingPathComponent("current.json")),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              abs(Date().timeIntervalSince1970 - snapshot.updated) < 3,
              !snapshot.tabs.isEmpty
        else { hide(); return }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.1)
        guard let value = attribute(application, kAXFocusedWindowAttribute), CFGetTypeID(value) == AXUIElementGetTypeID()
        else { hide(); return }
        let window = unsafeBitCast(value, to: AXUIElement.self)
        guard attribute(window, kAXTitleAttribute) as? String == snapshot.title,
              attribute(window, "AXFullScreen") as? Bool != true,
              attribute(window, kAXMinimizedAttribute) as? Bool != true,
              let frame = windowFrame(window),
              let screen = NSScreen.screens.max(by: { $0.frame.intersection(frame).area < $1.frame.intersection(frame).area })
        else { hide(); return }
        observe(pid: app.processIdentifier, window: window)
        let widths = snapshot.tabs.map { CGFloat(max(28, String($0.index + 1).count * 10 + 14)) }
        let width = widths.reduce(0, +) + CGFloat(max(0, widths.count - 1) * 4)
        guard let (tabFrame, clockFrame) = placement(frame: frame, visible: screen.visibleFrame, tabWidth: width)
        else { hide(); return }
        if currentTabs != snapshot.tabs || currentTitle != snapshot.title {
            currentTabs = snapshot.tabs
            currentTitle = snapshot.title
            let scroll = NSScrollView(frame: CGRect(origin: .zero, size: tabFrame.size))
            scroll.drawsBackground = false
            scroll.hasHorizontalScroller = false
            let content = NSView(frame: CGRect(x: 0, y: 0, width: width, height: 24))
            var x: CGFloat = 0
            for (tab, badgeWidth) in zip(snapshot.tabs, widths) {
                let button = Badge(label: String(tab.index + 1), active: tab.active) { [weak self] in
                    self?.write(Reply(title: snapshot.title, updated: Date().timeIntervalSince1970, tab_id: tab.id), name: "activate.json")
                }
                button.frame = CGRect(x: x, y: 0, width: badgeWidth, height: 24)
                content.addSubview(button)
                x += badgeWidth + 4
            }
            scroll.documentView = content
            tabsPanel.contentView = scroll
            if let active = snapshot.tabs.firstIndex(where: { $0.active }) {
                content.subviews[active].scrollToVisible(content.subviews[active].bounds)
            }
        }
        tabsPanel.setFrame(tabFrame, display: true)
        tabsPanel.orderFrontRegardless()
        if let clockFrame {
            let time = formatter.string(from: Date())
            if time != currentTime {
                currentTime = time
                clockPanel.contentView = Badge(label: time, active: true)
                clockPanel.ignoresMouseEvents = true
            }
            clockPanel.setFrame(clockFrame, display: true)
            clockPanel.orderFrontRegardless()
        } else { clockPanel.orderOut(nil) }
        let now = Date().timeIntervalSince1970
        if heartbeatTitle != snapshot.title || now - lastHeartbeat >= 0.5 {
            heartbeatTitle = snapshot.title
            lastHeartbeat = now
            write(Reply(title: snapshot.title, updated: now, tab_id: nil), name: "ready.json")
        }
    }
}

extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

if CommandLine.arguments.contains("--test") {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 944)
    let frame = CGRect(x: 45, y: 60, width: 1421, height: 864)
    let normal = placement(frame: frame, visible: screen, tabWidth: 92)!
    precondition(normal.0.minY < frame.maxY && normal.0.maxY > frame.maxY)
    precondition(normal.1!.midX == frame.midX)
    precondition(placement(frame: CGRect(x: 0, y: 0, width: 1512, height: 944), visible: screen, tabWidth: 30) == nil)
    precondition(placement(frame: frame, visible: screen, tabWidth: 1400)!.1 == nil)
    let second = frame.offsetBy(dx: -1512, dy: 300)
    precondition(placement(frame: second, visible: screen.offsetBy(dx: -1512, dy: 300), tabWidth: 30)!.0.minX == second.minX + 6)
    let fixture = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
    var changes = 0
    let watcher = watchDirectory(fixture) { changes += 1 }!
    for text in ["first snapshot", "replacement snapshot"] {
        let previous = changes
        try Data(text.utf8).write(to: fixture.appendingPathComponent("current.json"), options: .atomic)
        let deadline = Date().addingTimeInterval(1)
        while changes == previous && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.005))
        }
        precondition(changes > previous, "Atomic snapshot replacement must wake the observer")
    }
    watcher.cancel()
    try FileManager.default.removeItem(at: fixture)
    print("Floating tab geometry and snapshot notifications passed")
} else {
    let app = NSApplication.shared
    let companion = Companion()
    app.delegate = companion
    app.run()
}
