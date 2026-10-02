import AppKit
import ApplicationServices

struct Tab: Codable, Equatable {
    let id: Int
    let index: Int
    let active: Bool
}
struct Snapshot: Codable {
    let key: String
    let title: String
    let updated: Double
    let tabs: [Tab]
}
struct Reply: Codable {
    let title: String
    let updated: Double
    let tab_id: Int?
    var action: String? = nil
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
        setAccessibilityLabel(action == nil ? "Current time: \(label)" : (label == "+" ? "New WezTerm tab" : "WezTerm tab \(label)"))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    @objc func invoke() { actionHandler?() }
}

func needsOrdering(panel: Int, parent: Int, order: [Int]) -> Bool {
    guard let panelIndex = order.firstIndex(of: panel), let parentIndex = order.firstIndex(of: parent) else { return true }
    return panelIndex > parentIndex
}

final class OverlayPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .normal
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        isReleasedWhenClosed = false
    }
    // Clicks raise a native window within the normal level. Its focused overlay
    // must live above that level, otherwise it disappears until the next tick.
    func show(above number: Int, focused: Bool, order: [Int]) {
        let desiredLevel: NSWindow.Level = focused ? .floating : .normal
        let levelChanged = level != desiredLevel
        if levelChanged { level = desiredLevel }
        if focused {
            if levelChanged || !isVisible { orderFrontRegardless() }
        } else if levelChanged || !isVisible || needsOrdering(panel: windowNumber, parent: number, order: order) {
            self.order(.above, relativeTo: number)
        }
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// WezTerm's rectangular frame is clipped by macOS at the corners. Draw the
// missing arcs in small click-through panels instead of covering the terminal.
final class CornerOutline: NSView {
    static let diameter: CGFloat = 12
    let corner: Int
    init(corner: Int) {
        self.corner = corner
        super.init(frame: CGRect(x: 0, y: 0, width: Self.diameter, height: Self.diameter))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override func draw(_ dirtyRect: NSRect) {
        let right = corner % 2 == 1
        let top = corner >= 2
        let radius: CGFloat = 10
        let center = CGPoint(x: right ? bounds.width - radius - 0.5 : radius + 0.5,
                             y: top ? bounds.height - radius - 0.5 : radius + 0.5)
        let start: CGFloat = top ? (right ? 0 : 90) : (right ? 270 : 180)
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: start + 90)
        path.lineWidth = 1
        lavender.setStroke()
        path.stroke()
    }
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

final class WindowOverlay {
    let key: String
    let onChange: () -> Void
    init(key: String, onChange: @escaping () -> Void) { self.key = key; self.onChange = onChange }
    deinit {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        hide()
        for panel in corners + [tabsPanel, clockPanel] { panel.close() }
    }
    let tabsPanel = OverlayPanel()
    let clockPanel = OverlayPanel()
    let corners: [OverlayPanel] = (0..<4).map { corner in
        let panel = OverlayPanel()
        panel.ignoresMouseEvents = true
        panel.contentView = CornerOutline(corner: corner)
        return panel
    }
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

    func write(_ reply: Reply, name: String) {
        guard let data = try? JSONEncoder().encode(reply) else { return }
        try? data.write(to: stateDirectory.appendingPathComponent(name), options: .atomic)
    }

    func hide() {
        for panel in corners { panel.orderOut(nil) }
        hideBadges()
    }

    func hideBadges() {
        tabsPanel.orderOut(nil)
        clockPanel.orderOut(nil)
        if !heartbeatTitle.isEmpty {
            try? FileManager.default.removeItem(at: stateDirectory.appendingPathComponent("ready-\(key).json"))
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
            Unmanaged<WindowOverlay>.fromOpaque(context).takeUnretainedValue().onChange()
        }
        guard AXObserverCreate(pid, callback, &newObserver) == .success, let newObserver else { return }
        observer = newObserver
        for name in [kAXMovedNotification, kAXResizedNotification, kAXUIElementDestroyedNotification,
                     kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification] {
            _ = AXObserverAddNotification(newObserver, window, name as CFString, Unmanaged.passUnretained(self).toOpaque())
        }
        let application = AXUIElementCreateApplication(pid)
        _ = AXObserverAddNotification(newObserver, application, kAXFocusedWindowChangedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque())
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
    }

    func refresh(snapshot: Snapshot, window: AXUIElement, pid: pid_t, number: Int, focused: Bool, order: [Int]) {
        guard attribute(window, "AXFullScreen") as? Bool != true,
              attribute(window, kAXMinimizedAttribute) as? Bool != true,
              let frame = windowFrame(window),
              let screen = NSScreen.screens.max(by: { $0.frame.intersection(frame).area < $1.frame.intersection(frame).area })
        else { hide(); return }
        observe(pid: pid, window: window)
        let extent = CornerOutline.diameter
        for (index, panel) in corners.enumerated() {
            let position = CGRect(x: index % 2 == 1 ? frame.maxX - extent : frame.minX,
                                  y: index >= 2 ? frame.maxY - extent : frame.minY,
                                  width: extent, height: extent)
            if panel.frame != position { panel.setFrame(position, display: true) }
            panel.show(above: number, focused: focused, order: order)
        }
        let widths = snapshot.tabs.map { CGFloat(max(28, String($0.index + 1).count * 10 + 14)) }
        let width = widths.reduce(0, +) + CGFloat(widths.count * 4) + 28
        guard let (tabFrame, clockFrame) = placement(frame: frame, visible: screen.visibleFrame, tabWidth: width)
        else { hideBadges(); return }
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
                    _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                    NSRunningApplication(processIdentifier: pid)?.activate()
                    self?.write(Reply(title: snapshot.title, updated: Date().timeIntervalSince1970, tab_id: tab.id), name: "activate-\(snapshot.key).json")
                }
                button.frame = CGRect(x: x, y: 0, width: badgeWidth, height: 24)
                content.addSubview(button)
                x += badgeWidth + 4
            }
            let newTab = Badge(label: "+", active: false) { [weak self] in
                _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                NSRunningApplication(processIdentifier: pid)?.activate()
                self?.write(Reply(title: snapshot.title, updated: Date().timeIntervalSince1970,
                                  tab_id: nil, action: "new_tab"), name: "activate-\(snapshot.key).json")
            }
            newTab.frame = CGRect(x: x, y: 0, width: 28, height: 24)
            content.addSubview(newTab)
            scroll.documentView = content
            tabsPanel.contentView = scroll
            if let active = snapshot.tabs.firstIndex(where: { $0.active }) {
                content.subviews[active].scrollToVisible(content.subviews[active].bounds)
            }
        }
        if tabsPanel.frame != tabFrame { tabsPanel.setFrame(tabFrame, display: true) }
        tabsPanel.show(above: number, focused: focused, order: order)
        if let clockFrame {
            let time = formatter.string(from: Date())
            if time != currentTime {
                currentTime = time
                clockPanel.contentView = Badge(label: time, active: true)
                clockPanel.ignoresMouseEvents = true
            }
            if clockPanel.frame != clockFrame { clockPanel.setFrame(clockFrame, display: true) }
            clockPanel.show(above: number, focused: focused, order: order)
        } else { clockPanel.orderOut(nil) }
        let now = Date().timeIntervalSince1970
        if heartbeatTitle != snapshot.title || now - lastHeartbeat >= 0.5 {
            heartbeatTitle = snapshot.title
            lastHeartbeat = now
            write(Reply(title: snapshot.title, updated: now, tab_id: nil), name: "ready-\(key).json")
        }
    }
}

// Separate state and panels for each window, including windows of other GUI
// processes. Match only owner PID and geometry, without reading screen content.
final class Companion: NSObject, NSApplicationDelegate {
    var overlays: [String: WindowOverlay] = [:]
    var timer: Timer?
    var stateWatcher: DispatchSourceFileSystemObject?
    var refreshing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        stateWatcher = watchDirectory(stateDirectory) { [weak self] in self?.refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: name, object: nil)
        }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) { overlays.removeAll() }

    @objc func refresh() {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        let identifiers = ["org.wezfurlong.wezterm", "com.github.wez.wezterm"]
        guard AXIsProcessTrusted(), let front = NSWorkspace.shared.frontmostApplication,
              identifiers.contains(front.bundleIdentifier ?? "") else {
            for overlay in overlays.values { overlay.hide() }
            return
        }
        let now = Date().timeIntervalSince1970
        let files = (try? FileManager.default.contentsOfDirectory(at: stateDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        var snapshots: [String: Snapshot] = [:]
        for file in files where file.lastPathComponent.hasPrefix("window-") && file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
                  file.lastPathComponent == "window-\(snapshot.key).json",
                  snapshot.key.range(of: "^[A-Za-z0-9]+-[0-9]+$", options: .regularExpression) != nil else { continue }
            if now - snapshot.updated > 30 {
                for name in ["window-", "ready-", "activate-"] {
                    try? FileManager.default.removeItem(at: stateDirectory.appendingPathComponent("\(name)\(snapshot.key).json"))
                }
                continue
            }
            if abs(now - snapshot.updated) < 3 && !snapshot.tabs.isEmpty { snapshots[snapshot.title] = snapshot }
        }
        let visible = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let order = visible.compactMap { $0[kCGWindowNumber as String] as? Int }
        var live = Set<String>()
        for app in NSWorkspace.shared.runningApplications where identifiers.contains(app.bundleIdentifier ?? "") {
            let application = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(application, 0.1)
            guard let windows = attribute(application, kAXWindowsAttribute) as? [AXUIElement] else { continue }
            let focusedWindow = attribute(application, kAXFocusedWindowAttribute)
            for window in windows {
                guard let title = attribute(window, kAXTitleAttribute) as? String,
                      let snapshot = snapshots[title], let frame = windowFrame(window),
                      let entry = visible.first(where: { info in
                          guard (info[kCGWindowOwnerPID as String] as? Int) == Int(app.processIdentifier),
                                (info[kCGWindowLayer as String] as? Int) == 0,
                                let bounds = info[kCGWindowBounds as String] as? [String: Any],
                                let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
                          let top = NSScreen.screens.first?.frame.maxY ?? 0
                          return abs(rect.minX - frame.minX) < 2 && abs(top - rect.maxY - frame.minY) < 2
                              && abs(rect.width - frame.width) < 2 && abs(rect.height - frame.height) < 2
                      }), let number = entry[kCGWindowNumber as String] as? Int else { continue }
                live.insert(snapshot.key)
                let overlay = overlays[snapshot.key] ?? WindowOverlay(key: snapshot.key) { [weak self] in self?.refresh() }
                overlays[snapshot.key] = overlay
                let focused = app.processIdentifier == front.processIdentifier
                    && focusedWindow.map { CFEqual($0, window) } == true
                overlay.refresh(snapshot: snapshot, window: window, pid: app.processIdentifier,
                    number: number, focused: focused, order: order)
            }
        }
        for key in Array(overlays.keys) where !live.contains(key) { overlays.removeValue(forKey: key) }
    }
}

extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

if let argument = CommandLine.arguments.firstIndex(of: "--render-corners"),
   CommandLine.arguments.count > argument + 1 {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 120, pixelsHigh: 120,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: 60, height: 60)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor.black.setFill()
    NSRect(x: 0, y: 0, width: 60, height: 60).fill()
    let context = NSGraphicsContext.current!.cgContext
    context.translateBy(x: 20, y: 20)
    let corner = CornerOutline(corner: 0)
    corner.draw(corner.bounds)
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(
        to: URL(fileURLWithPath: CommandLine.arguments[argument + 1]))
} else if CommandLine.arguments.contains("--test") {
    precondition(needsOrdering(panel: 2, parent: 1, order: [1, 2]), "Click-raised window needs its normal-level panel restored")
    precondition(!needsOrdering(panel: 2, parent: 1, order: [3, 2, 1]), "Correctly stacked background panels must not be reordered")
    precondition(needsOrdering(panel: 2, parent: 1, order: [1]), "Hidden panels must be restored")
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
