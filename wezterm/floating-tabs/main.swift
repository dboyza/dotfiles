// Follow macOS WezTerm windows with native badges and a clock.
import AppKit
import ApplicationServices

// Section: Bridge payloads and validation
struct Tab: Codable, Equatable {
    let id: Int
    let index: Int
    let active: Bool
    // Optional display hints: the program or folder name, and a background-activity flag.
    var label: String? = nil
    var alert: Bool? = nil
    var branch: String? = nil
    var path: String? = nil
    // 0...100 with a state of normal, error, or indeterminate (no percent).
    var progress: Int? = nil
    var progress_state: String? = nil
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
    var index: Int? = nil
}

// Keep these limits aligned with config/protocol.lua and the shared fixtures.
let freshnessSeconds: Double = 3
let maximumSnapshotBytes = 65536
let maximumLabelBytes = 64
let maximumBranchBytes = 64
let maximumPathBytes = 256
let progressStates: Set<String> = ["normal", "error", "indeterminate"]
let cleanupAfterSeconds: Double = 30
// How long after an app activation or Space change to watch for windows the system slides away.
let motionWatchSeconds: Double = 0.6
// How long live following continues after a window's on-screen bounds stop changing.
let followSeconds: Double = 0.3

func validSnapshot(_ snapshot: Snapshot, filename: String, now: Double) -> Bool {
    let validKey = snapshot.key.range(of: "^[A-Za-z0-9]+-[0-9]+$", options: .regularExpression) != nil
    let title = "WezTerm [\(snapshot.key.replacingOccurrences(of: "-", with: ":"))]"
    let validTabs = !snapshot.tabs.isEmpty && snapshot.tabs.allSatisfy {
        $0.id >= 0 && $0.id <= 9007199254740991 && $0.index >= 0 && $0.index <= 2147483647
            && ($0.label?.utf8.count ?? 0) <= maximumLabelBytes
            && ($0.branch?.utf8.count ?? 0) <= maximumBranchBytes && ($0.path?.utf8.count ?? 0) <= maximumPathBytes
            && ($0.progress.map { (0...100).contains($0) } ?? true) && ($0.progress_state.map { progressStates.contains($0) } ?? true)
    }
    return validKey && filename == "window-\(snapshot.key).json" && snapshot.title == title
        && abs(now - snapshot.updated) < freshnessSeconds && validTabs
        && Set(snapshot.tabs.map { $0.id }).count == snapshot.tabs.count
        && Set(snapshot.tabs.map { $0.index }).count == snapshot.tabs.count
        && snapshot.tabs.filter { $0.active }.count == 1
}

func testSnapshotContract(_ path: String) throws {
    struct Case: Decodable {
        let name: String, file: String, payload: String
        let now: Double
        let valid: Bool
    }
    struct Fixtures: Decodable { let snapshots: [Case] }
    let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    for fixture in fixtures.snapshots {
        let snapshot = try? JSONDecoder().decode(Snapshot.self, from: Data(fixture.payload.utf8))
        let valid = snapshot.map { validSnapshot($0, filename: fixture.file, now: fixture.now) } ?? false
        precondition(valid == fixture.valid, "Snapshot contract: \(fixture.name)")
    }
}

// Section: State location and palette
let stateDirectory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/state/dotfiles/wezterm-floating-tabs")
// BEGIN generated palette (edit theme/palette.json, then run scripts/sync-palette.py)
enum Palette {
    static let deep = NSColor(srgbRed: 25/255, green: 23/255, blue: 36/255, alpha: 1)
    static let base = NSColor(srgbRed: 35/255, green: 33/255, blue: 54/255, alpha: 1)
    static let surface = NSColor(srgbRed: 42/255, green: 39/255, blue: 63/255, alpha: 1)
    static let overlay = NSColor(srgbRed: 57/255, green: 53/255, blue: 82/255, alpha: 1)
    static let muted = NSColor(srgbRed: 110/255, green: 106/255, blue: 134/255, alpha: 1)
    static let subtle = NSColor(srgbRed: 144/255, green: 140/255, blue: 170/255, alpha: 1)
    static let text = NSColor(srgbRed: 224/255, green: 222/255, blue: 244/255, alpha: 1)
    static let bright = NSColor(srgbRed: 238/255, green: 236/255, blue: 255/255, alpha: 1)
    static let love = NSColor(srgbRed: 235/255, green: 111/255, blue: 146/255, alpha: 1)
    static let gold = NSColor(srgbRed: 246/255, green: 193/255, blue: 119/255, alpha: 1)
    static let rose = NSColor(srgbRed: 234/255, green: 154/255, blue: 151/255, alpha: 1)
    static let blush = NSColor(srgbRed: 235/255, green: 188/255, blue: 186/255, alpha: 1)
    static let pine = NSColor(srgbRed: 62/255, green: 143/255, blue: 176/255, alpha: 1)
    static let foam = NSColor(srgbRed: 156/255, green: 207/255, blue: 216/255, alpha: 1)
    static let iris = NSColor(srgbRed: 196/255, green: 167/255, blue: 231/255, alpha: 1)
    static let highlight = NSColor(srgbRed: 68/255, green: 65/255, blue: 90/255, alpha: 1)
    static let cursorline = NSColor(srgbRed: 49/255, green: 43/255, blue: 68/255, alpha: 1)
    static let cursorline_nr = NSColor(srgbRed: 58/255, green: 49/255, blue: 72/255, alpha: 1)
    static let cursor = NSColor(srgbRed: 255/255, green: 255/255, blue: 255/255, alpha: 1)
}
// END generated palette
let lavender = Palette.iris
let dark = Palette.deep
let muted = Palette.overlay
let subtle = Palette.subtle
let surface = Palette.base.withAlphaComponent(0.9)
let bright = Palette.text
let rose = Palette.love

// Section: Native window observation and placement
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
// Panels are taller than their 24-point pills so shadows are not clipped.
let panelHeight: CGFloat = 30
func placement(frame: CGRect, visible: CGRect, tabWidth: CGFloat, clockWidth: CGFloat = 88) -> (CGRect, CGRect?)? {
    let y = frame.maxY - panelHeight / 2
    guard y + panelHeight <= visible.maxY, frame.width >= 48 else { return nil }
    let tabs = CGRect(x: frame.minX + 6, y: y, width: min(tabWidth, frame.width - 12), height: panelHeight)
    let clock = CGRect(x: frame.midX - clockWidth / 2, y: y, width: clockWidth, height: panelHeight)
    return (tabs, tabs.maxX + 12 < clock.minX ? clock : nil)
}

// Clock drags stop where the strip still fits above the window, instead of pushing it under the menu bar.
// Takes and returns an AX position (top-left origin); `visible` is in AppKit coordinates.
func clampedDragPosition(_ point: CGPoint, visible: CGRect, top: CGFloat = NSScreen.screens.first?.frame.maxY ?? 0) -> CGPoint {
    CGPoint(x: point.x, y: max(point.y, top - visible.maxY + panelHeight / 2))
}

// The macOS launch geometry from config/geometry.lua: centered at 94% by 88% of the screen.
// Returns AX bounds (top-left origin) for a screen frame in AppKit coordinates.
func launchBounds(screen: CGRect, top: CGFloat = NSScreen.screens.first?.frame.maxY ?? 0) -> CGRect {
    let width = floor(screen.width * 0.94), height = floor(screen.height * 0.88)
    let x = screen.minX + floor((screen.width - width) / 2)
    let y = top - screen.maxY + floor((screen.height - height) / 2)
    return CGRect(x: x, y: y, width: width, height: height)
}

// Section: Badge model and pointer plumbing
// What a pill shows; comparing models lets the strip skip work when nothing changed.
struct BadgeModel: Equatable {
    var number = ""
    var label: String?
    var branch: String?
    var path: String?
    var active = false
    var alert = false
    var progress: Int?
    var progressState: String?
    var compact = true
    init(number: String) { self.number = number }
    init(tab: Tab, compact: Bool) {
        number = String(tab.index + 1)
        label = tab.label
        branch = tab.branch
        path = tab.path
        active = tab.active
        alert = tab.alert ?? false
        progress = tab.progress
        progressState = tab.progress_state
        self.compact = compact
    }
}

// Menu items keep their closure alive through `representedObject`.
final class MenuAction: NSObject {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
    @objc func fire() { run() }
}

enum DragPhase { case began, moved, ended }

// Section: Badge and overlay drawing
// Pills are frosted glass under a tint; the tint, text, dots, and progress ring fade between states.
final class Badge: NSView {
    enum Kind { case tab, plus, clock }
    static let pillHeight: CGFloat = 24
    static let verticalInset = (panelHeight - pillHeight) / 2

    let kind: Kind
    var onClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onClose: (() -> Void)?
    var onDrag: ((DragPhase, CGFloat) -> Void)?
    // The clock drags its terminal window, reporting the pointer in screen coordinates.
    var onWindowDrag: ((DragPhase, CGPoint) -> Void)?
    var menuItems: (() -> [(String, () -> Void)])?
    private(set) var hovered = false
    private var model = BadgeModel(number: "")
    private let glass = NSVisualEffectView()
    // AppKit orders subview layers itself, so the tint and text live in a view stacked above the glass.
    private let content = NSView()
    private let tint = CALayer()
    private let numberLayer = CATextLayer()
    private let labelLayer = CATextLayer()
    private let branchLayer = CATextLayer()
    private let dot = CALayer()
    private let closeLayer = CATextLayer()
    private let ringTrack = CAShapeLayer()
    private let ringArc = CAShapeLayer()
    private var pressed = false, dragging = false
    private var pressOffset: CGFloat = 0
    private var pressOrigin = CGPoint.zero

    private var named: Bool { kind == .tab && !model.compact && model.label != nil }
    var isNamed: Bool { named }

    static func font(_ size: CGFloat, bold: Bool) -> NSFont {
        let weight = bold ? 9 : 5
        for family in ["JetBrainsMono Nerd Font", "JetBrainsMono NF"] {
            if let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: weight, size: size) { return font }
        }
        return .monospacedSystemFont(ofSize: size, weight: bold ? .semibold : .medium)
    }
    static func textWidth(_ text: String, size: CGFloat) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font(size, bold: true)]).width)
    }
    // The branch glyph is Nerd Font private-use text, drawn dimmer after the label.
    static func branchText(_ branch: String) -> String { "\u{e0a0} " + branch }
    // Numbers alone stay compact; a labeled tab also names its branch and gets a slot for the dot, ring, or close button.
    static func width(_ model: BadgeModel) -> CGFloat {
        if model.compact || model.label == nil { return max(28, CGFloat(model.number.count * 10 + 14)) }
        let label = model.label.map { 6 + textWidth($0, size: 12) } ?? 0
        let branch = model.branch.map { 6 + textWidth(branchText($0), size: 11) } ?? 0
        return 10 + textWidth(model.number, size: 13) + label + branch + 6 + 12 + 6
    }

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = kind == .clock ? 0.2 : 0.3
        layer?.shadowRadius = 3
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.appearance = NSAppearance(named: .darkAqua)
        addSubview(glass)
        content.wantsLayer = true
        content.layer?.masksToBounds = false
        addSubview(content)
        tint.cornerRadius = Badge.pillHeight / 2
        content.layer?.addSublayer(tint)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        for item in [numberLayer, labelLayer, branchLayer, closeLayer] {
            item.contentsScale = scale
            item.truncationMode = .end
            content.layer?.addSublayer(item)
        }
        closeLayer.string = "×"
        closeLayer.alignmentMode = .center
        closeLayer.opacity = 0
        dot.backgroundColor = rose.cgColor
        dot.cornerRadius = 3
        dot.opacity = 0
        content.layer?.addSublayer(dot)
        for ring in [ringTrack, ringArc] {
            ring.fillColor = nil
            ring.lineWidth = 2
            ring.lineCap = .round
            ring.opacity = 0
            content.layer?.addSublayer(ring)
        }
        ringArc.strokeEnd = 0
        let mask = NSImage(size: NSSize(width: Badge.pillHeight, height: Badge.pillHeight), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        mask.resizingMode = .stretch
        glass.maskImage = mask
        apply(BadgeModel(number: kind == .plus ? "+" : ""), animated: false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func apply(_ next: BadgeModel, animated: Bool = true) {
        guard !animated || next != model else { return }
        let relayout = next.compact != model.compact || next.label != model.label || next.number != model.number
            || next.branch != model.branch
        model = next
        toolTip = next.path
        if relayout { needsLayout = true }
        restyle(animated: animated)
    }

    // Clocks show the time dimly; hovering swaps in the date. The colon pulses once a second.
    func setClock(_ time: String, colonVisible: Bool) {
        let font = Badge.font(12, bold: false)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let result = NSMutableAttributedString(string: time, attributes: [
            .font: font, .foregroundColor: subtle, .paragraphStyle: style])
        if !colonVisible, let colon = time.firstIndex(of: ":") {
            result.addAttribute(.foregroundColor, value: subtle.withAlphaComponent(0.3),
                                range: NSRange(colon...colon, in: time))
        }
        numberLayer.alignmentMode = .center
        numberLayer.string = result
    }

    // Section: State styling
    private func restyle(animated: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.14)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        let hot = hovered && kind != .clock
        if kind == .clock {
            tint.backgroundColor = dark.withAlphaComponent(0.5).cgColor
            // Outline the clock in the window border's lavender so the two read as one frame.
            tint.borderWidth = 1
            tint.borderColor = subtle.cgColor
        } else if model.active {
            tint.backgroundColor = lavender.withAlphaComponent(0.96).cgColor
            tint.borderWidth = 0
        } else {
            tint.backgroundColor = (hot ? muted.withAlphaComponent(0.85) : surface.withAlphaComponent(0.55)).cgColor
            tint.borderWidth = 0.5
            tint.borderColor = muted.withAlphaComponent(hot ? 0.9 : 0.7).cgColor
        }
        let ink = model.active ? dark : (hot ? bright : subtle)
        if kind != .clock {
            numberLayer.string = model.number
            numberLayer.font = Badge.font(13, bold: model.active)
            numberLayer.fontSize = 13
            numberLayer.foregroundColor = ink.cgColor
            numberLayer.alignmentMode = named ? .left : .center
            labelLayer.string = model.label
            labelLayer.font = Badge.font(12, bold: false)
            labelLayer.fontSize = 12
            labelLayer.foregroundColor = ink.withAlphaComponent(model.active ? 0.85 : 1).cgColor
            labelLayer.isHidden = !named
            branchLayer.string = model.branch.map(Badge.branchText)
            branchLayer.font = Badge.font(11, bold: false)
            branchLayer.fontSize = 11
            branchLayer.foregroundColor = ink.withAlphaComponent(model.active ? 0.6 : 0.7).cgColor
            branchLayer.isHidden = !named || model.branch == nil
        }
        closeLayer.font = Badge.font(14, bold: true)
        closeLayer.fontSize = 14
        closeLayer.foregroundColor = ink.cgColor
        let showClose = named && hovered && onClose != nil
        closeLayer.opacity = showClose ? 1 : 0
        let ringed = model.progressState != nil && kind == .tab
        dot.opacity = model.alert && !model.active && !showClose && !ringed ? 1 : 0
        restyleRing(ink: ink, visible: ringed && !showClose)
        CATransaction.commit()
        setAccessibilityLabel(kind == .clock ? "Current time" : (kind == .plus ? "New WezTerm tab"
            : "WezTerm tab \(model.number)\(model.label.map { " " + $0 } ?? "")"))
    }

    // Programs report progress through the terminal; a ring shows the percent, or spins when unknown.
    private func restyleRing(ink: NSColor, visible: Bool) {
        ringTrack.opacity = visible ? 0.3 : 0
        ringArc.opacity = visible ? 1 : 0
        let color = (model.progressState == "error" ? rose : (model.active ? dark : Palette.foam)).cgColor
        ringTrack.strokeColor = ink.cgColor
        ringArc.strokeColor = color
        if model.progressState == "indeterminate" {
            ringArc.strokeEnd = 0.3
            if ringArc.animation(forKey: "spin") == nil {
                let spin = CABasicAnimation(keyPath: "transform.rotation.z")
                spin.fromValue = 0
                spin.toValue = -2 * Double.pi
                spin.duration = 1
                spin.repeatCount = .infinity
                ringArc.add(spin, forKey: "spin")
            }
        } else {
            ringArc.removeAnimation(forKey: "spin")
            ringArc.strokeEnd = CGFloat(model.progress ?? 0) / 100
        }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let pill = CGRect(x: 0, y: Badge.verticalInset, width: bounds.width, height: Badge.pillHeight)
        glass.frame = pill
        content.frame = bounds
        tint.frame = pill
        layer?.shadowPath = CGPath(roundedRect: pill, cornerWidth: pill.height / 2, cornerHeight: pill.height / 2, transform: nil)
        let line = ceil(Badge.font(13, bold: false).boundingRectForFont.height)
        let textY = pill.minY + ((pill.height - line) / 2).rounded()
        let numberWidth = Badge.textWidth(model.number, size: 13)
        numberLayer.frame = named ? CGRect(x: 10, y: textY, width: numberWidth + 2, height: line)
                                  : CGRect(x: 0, y: textY, width: pill.width, height: line)
        let slotX = pill.width - 6 - 12
        let labelX = 10 + numberWidth + 6
        let labelWidth = model.label.map { Badge.textWidth($0, size: 12) + 2 } ?? 0
        labelLayer.frame = CGRect(x: labelX, y: textY + 0.5, width: min(labelWidth, max(0, slotX - labelX - 2)), height: line)
        let branchX = labelX + labelWidth + 4
        branchLayer.frame = CGRect(x: branchX, y: textY + 1, width: max(0, slotX - branchX - 2), height: line)
        closeLayer.frame = CGRect(x: slotX, y: textY, width: 12, height: line)
        dot.frame = named ? CGRect(x: slotX + 3, y: pill.midY - 3, width: 6, height: 6)
                          : CGRect(x: pill.maxX - 10, y: pill.maxY - 10, width: 6, height: 6)
        // The ring replaces the dot's spot: the right-hand slot when named, the upper corner when compact.
        let size: CGFloat = named ? 12 : 9
        let center = named ? CGPoint(x: slotX + 6, y: pill.midY) : CGPoint(x: pill.maxX - 7, y: pill.maxY - 7)
        for ring in [ringTrack, ringArc] {
            ring.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            ring.position = center
            let inner = (size - ring.lineWidth) / 2
            let path = CGMutablePath()
            path.addArc(center: CGPoint(x: size / 2, y: size / 2), radius: inner, startAngle: .pi / 2,
                        endAngle: .pi / 2 - 2 * .pi, clockwise: true)
            ring.path = path
        }
        CATransaction.commit()
    }

    // Section: Pointer handling
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    func setHovered(_ value: Bool) {
        guard value != hovered else { return }
        hovered = value
        restyle(animated: true)
    }
    override func mouseEntered(with event: NSEvent) {
        setHovered(true)
        if kind == .clock && !dragging { NSCursor.openHand.set() }
    }
    override func mouseExited(with event: NSEvent) {
        setHovered(false)
        if kind == .clock && !dragging { NSCursor.arrow.set() }
    }

    // A press activates on release, so dragging a tab to reorder it does not also switch to it.
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if named && hovered && point.x >= bounds.width - 24, let onClose { onClose(); return }
        pressed = true
        dragging = false
        pressOffset = point.x
        pressOrigin = event.locationInWindow
    }
    override func mouseDragged(with event: NSEvent) {
        if pressed, kind == .clock, let onWindowDrag {
            if !dragging {
                dragging = true
                NSCursor.closedHand.set()
                onWindowDrag(.began, NSEvent.mouseLocation)
            }
            onWindowDrag(.moved, NSEvent.mouseLocation)
            return
        }
        guard pressed, kind == .tab, let onDrag else { return }
        if !dragging {
            guard abs(event.locationInWindow.x - pressOrigin.x) > 4 else { return }
            dragging = true
            onDrag(.began, 0)
        }
        let origin = (superview?.convert(event.locationInWindow, from: nil).x ?? 0) - pressOffset
        onDrag(.moved, origin)
    }
    override func mouseUp(with event: NSEvent) {
        defer { pressed = false; dragging = false }
        // Like a button, releasing outside the pill cancels the click.
        if dragging && kind == .clock {
            onWindowDrag?(.ended, NSEvent.mouseLocation)
            (bounds.contains(convert(event.locationInWindow, from: nil)) ? NSCursor.openHand : NSCursor.arrow).set()
        } else if dragging { onDrag?(.ended, 0) } else if pressed && bounds.contains(convert(event.locationInWindow, from: nil)) {
            if event.clickCount == 2, let onDoubleClick { onDoubleClick() } else { onClick?() }
        }
    }
    // Middle-click closes a tab with the usual confirmation.
    override func otherMouseUp(with event: NSEvent) {
        if event.buttonNumber == 2 { onClose?() }
    }
    override func rightMouseDown(with event: NSEvent) {
        guard kind == .tab, let items = menuItems?() else { return }
        let menu = NSMenu()
        for (title, run) in items {
            if title == "-" { menu.addItem(.separator()); continue }
            let action = MenuAction(run)
            let item = NSMenuItem(title: title, action: #selector(MenuAction.fire), keyEquivalent: "")
            item.target = action
            item.representedObject = action
            menu.addItem(item)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

// Section: Tab strip with animated updates and drag-to-reorder
// Badges are reused by tab ID so selection fades and openings and closings slide instead of rebuilding.
final class TabStrip: NSView {
    struct Handlers {
        var activate: (Tab) -> Void
        var close: (Tab) -> Void
        var move: (Tab, Int) -> Void
        var action: (Tab, String) -> Void
        var newTab: () -> Void
    }

    private var badges: [Int: Badge] = [:]
    private var targets: [Int: CGRect] = [:]
    private let plus = Badge(kind: .plus)
    func badge(for id: Int) -> Badge? { badges[id] }
    func slotTarget(_ id: Int) -> CGRect? { targets[id] }
    private var activeID: Int?
    private var populated = false
    private var shown: [Tab] = []
    private var compact = false
    private var handlers: Handlers?
    // While a drag runs the strip lays itself out; afterward the dropped order holds until the snapshot catches up.
    private var drag: (id: Int, drop: Int)?
    private var pendingOrder: [Int]?
    private var pendingUntil = Date.distantPast

    static func widths(_ tabs: [Tab], compact: Bool) -> [CGFloat] {
        tabs.map { Badge.width(BadgeModel(tab: $0, compact: compact)) }
    }
    // Leave room on each side for the badges' shadows, which the scroll view would otherwise clip.
    static let margin: CGFloat = 3
    static func totalWidth(_ widths: [CGFloat]) -> CGFloat {
        widths.reduce(0, +) + CGFloat(widths.count * 4) + 28 + margin * 2
    }

    // Slot frames for tabs laid out in the given order.
    private func slots(_ order: [Tab]) -> [Int: CGRect] {
        var result: [Int: CGRect] = [:]
        var x = TabStrip.margin
        for (tab, width) in zip(order, TabStrip.widths(order, compact: compact)) {
            result[tab.id] = CGRect(x: x, y: 0, width: width, height: panelHeight)
            x += width + 4
        }
        result[-1] = CGRect(x: x, y: 0, width: 28, height: panelHeight)
        return result
    }

    func update(tabs: [Tab], compact: Bool, handlers: Handlers) {
        self.compact = compact
        self.handlers = handlers
        // Display follows tab indices even if a snapshot lists them out of order.
        let tabs = tabs.sorted { $0.index < $1.index }
        var ordered = tabs
        if let current = drag, !tabs.contains(where: { $0.id == current.id }) { drag = nil }
        if let pending = pendingOrder {
            let ids = tabs.map { $0.id }
            if ids == pending || Date() >= pendingUntil || Set(ids) != Set(pending) {
                pendingOrder = nil
            } else {
                ordered = pending.compactMap { id in tabs.first { $0.id == id } }
            }
        }
        shown = ordered
        let layout = slots(ordered)
        var seen = Set<Int>()
        for tab in ordered {
            seen.insert(tab.id)
            let target = layout[tab.id]!
            let badge = badges[tab.id] ?? makeBadge(tab.id, at: target)
            badge.onClick = { handlers.activate(tab) }
            badge.onClose = { handlers.close(tab) }
            badge.menuItems = {
                [("Rename…", { handlers.action(tab, "rename_tab") }), ("Duplicate", { handlers.action(tab, "duplicate_tab") }),
                 ("Move to New Window", { handlers.action(tab, "detach_tab") }), ("-", {}),
                 ("Close", { handlers.close(tab) })]
            }
            badge.onDrag = { [weak self] phase, origin in self?.drag(tab.id, phase, origin) }
            badge.apply(BadgeModel(tab: tab, compact: compact))
            if drag == nil { move(badge, id: tab.id, to: target) }
        }
        for id in badges.keys where !seen.contains(id) {
            guard let gone = badges.removeValue(forKey: id) else { continue }
            targets.removeValue(forKey: id)
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.12; gone.animator().alphaValue = 0 },
                                                 completionHandler: { gone.removeFromSuperview() })
        }
        plus.onClick = handlers.newTab
        if plus.superview == nil { addSubview(plus) }
        if drag == nil { move(plus, id: -1, to: layout[-1]!) }
        frame.size = CGSize(width: layout[-1]!.maxX + TabStrip.margin, height: panelHeight)
        if let active = tabs.first(where: { $0.active })?.id, active != activeID {
            activeID = active
            if let badge = badges[active] { scrollToVisible(badge.frame) }
        }
        populated = true
    }

    private func makeBadge(_ id: Int, at target: CGRect) -> Badge {
        let badge = Badge(kind: .tab)
        badge.frame = target
        addSubview(badge)
        badges[id] = badge
        if populated {
            badge.alphaValue = 0
            NSAnimationContext.runAnimationGroup { $0.duration = 0.16; badge.animator().alphaValue = 1 }
        }
        return badge
    }

    private func move(_ badge: Badge, id: Int, to target: CGRect) {
        guard targets[id] != target else { return }
        targets[id] = target
        if badge.superview == nil || !populated || badge.frame.isEmpty { badge.frame = target; return }
        NSAnimationContext.runAnimationGroup { $0.duration = 0.16; badge.animator().frame = target }
    }

    // Section: Drag to reorder
    // The dragged pill follows the pointer while its neighbors slide apart to show where it will land.
    func drag(_ id: Int, _ phase: DragPhase, _ origin: CGFloat) {
        guard let badge = badges[id], let from = shown.firstIndex(where: { $0.id == id }) else { return }
        // Snapshots can open or close tabs mid-drag, so the order is rebuilt from the current tabs every time.
        let others = shown.filter { $0.id != id }
        let dropping = { (drop: Int) -> [Tab] in
            var order = others
            order.insert(self.shown[from], at: min(drop, others.count))
            return order
        }
        switch phase {
        case .began:
            drag = (id, from)
            addSubview(badge, positioned: .above, relativeTo: nil)
            badge.alphaValue = 0.92
        case .moved:
            guard let current = drag, current.id == id else { return }
            let limit = (targets[-1]?.minX ?? bounds.width) - badge.frame.width - 4
            badge.frame.origin.x = min(max(TabStrip.margin, origin), max(TabStrip.margin, limit))
            // Compare the pill's leading edge, not its center, so a wide pill can still pass a narrow end tab.
            let home = slots(shown)[id]?.minX ?? badge.frame.minX
            let edge = badge.frame.minX < home ? badge.frame.minX : badge.frame.minX > home ? badge.frame.maxX : badge.frame.midX
            var cursor = TabStrip.margin
            var drop = 0
            for width in TabStrip.widths(others, compact: compact) {
                if edge > cursor + width / 2 { drop += 1 }
                cursor += width + 4
            }
            if drop != current.drop {
                drag = (id, drop)
                for (key, target) in slots(dropping(drop)) where key != id {
                    if let other = key == -1 ? plus : badges[key] { move(other, id: key, to: target) }
                }
            }
        case .ended:
            guard let current = drag, current.id == id else { return }
            drag = nil
            badge.alphaValue = 1
            let drop = min(current.drop, others.count)
            let reordered = dropping(drop)
            // The pill was dragged by hand, so its recorded slot is stale: always glide it back into place.
            targets[id] = nil
            layOut(reordered)
            if drop != from {
                // Hold the dropped order until WezTerm publishes it, so the strip does not snap back first.
                pendingOrder = reordered.map { $0.id }
                pendingUntil = Date().addingTimeInterval(1.5)
                shown = reordered
                handlers?.move(shown[drop], drop)
            }
        }
    }

    // Hidden panels miss pointer exits and releases, so forget hover and any drag in progress.
    func resetPointer() {
        for badge in badges.values { badge.setHovered(false) }
        plus.setHovered(false)
        guard let current = drag else { return }
        drag = nil
        badges[current.id]?.alphaValue = 1
        targets[current.id] = nil
        layOut(shown)
    }

    private func layOut(_ order: [Tab]) {
        for (key, target) in slots(order) {
            if let view = key == -1 ? plus : badges[key] { move(view, id: key, to: target) }
        }
    }
}

func needsOrdering(panel: Int, parent: Int, order: [Int]) -> Bool {
    guard let panelIndex = order.firstIndex(of: panel), let parentIndex = order.firstIndex(of: parent) else { return true }
    return panelIndex > parentIndex
}

// CoreGraphics bounds (top-left origin) of each listed window, by window number.
func windowBounds(_ windows: [[String: Any]]) -> [Int: CGRect] {
    var result: [Int: CGRect] = [:]
    for info in windows {
        guard let number = info[kCGWindowNumber as String] as? Int,
              let bounds = info[kCGWindowBounds as String] as? [String: Any],
              let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { continue }
        result[number] = rect
    }
    return result
}

// The first unclaimed CoreGraphics window (top-left origin) whose bounds match an AX frame (bottom-left origin).
func matchWindow(frame: CGRect, candidates: [(Int, CGRect)], claimed: Set<Int>,
                 top: CGFloat = NSScreen.screens.first?.frame.maxY ?? 0) -> Int? {
    candidates.first { number, rect in
        !claimed.contains(number) && abs(rect.minX - frame.minX) < 2 && abs(top - rect.maxY - frame.minY) < 2
            && abs(rect.width - frame.width) < 2 && abs(rect.height - frame.height) < 2
    }?.0
}

// Show Desktop and Mission Control move windows on screen while AX still reports the old frame.
func displaced(_ matched: CGRect?, _ current: CGRect?) -> Bool {
    guard let matched, let current else { return false }
    return abs(matched.minX - current.minX) >= 2 || abs(matched.minY - current.minY) >= 2
        || abs(matched.width - current.width) >= 2 || abs(matched.height - current.height) >= 2
}

// An unmatched overlay lasts as long as its window and snapshot, so focus and Space changes never tear it down.
// Off-screen or system-moved windows park; a visible window whose AX reads time out keeps a grace period.
enum OverlayFate { case keep, park, remove }
func overlayFate(fresh: Bool, exists: Bool, onScreen: Bool, moved: Bool, unreadable: Bool, unseenFor: Double) -> OverlayFate {
    guard fresh, exists else { return .remove }
    guard onScreen && !moved && unreadable else { return .park }
    // AX times out while WezTerm changes focus; only a lasting failure falls back to native tabs.
    return unseenFor < freshnessSeconds ? .keep : .remove
}

final class OverlayPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .normal
        hidesOnDeactivate = false
        // Panels belong to their window's Space so they slide with it when switching desktops.
        collectionBehavior = [.managed, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        isReleasedWhenClosed = false
        // The system zoom-fade would make every reorder or level change look like a flicker.
        animationBehavior = .none
    }
    // Clicks raise a native window within the normal level. Its focused overlay
    // must live above that level, otherwise it disappears until the next tick.
    func show(above number: Int, focused: Bool, order: [Int]) {
        // A panel left on another Space (its window moved) is ordered back in on the current one.
        if isVisible && !isOnActiveSpace { orderOut(nil) }
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

// Section: Per-window rendering and click requests
final class WindowOverlay {
    let key: String
    // Called with true when the window moved or resized, which live following handles.
    let onChange: (Bool) -> Void
    init(key: String, onChange: @escaping (Bool) -> Void) { self.key = key; self.onChange = onChange }
    deinit {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        hide()
        for panel in [tabsPanel, clockPanel] { panel.close() }
    }
    let tabsPanel = OverlayPanel()
    // Clicking the clock focuses its window and dragging it moves the window.
    let clockPanel = OverlayPanel()
    let strip = TabStrip()
    let clockBadge = Badge(kind: .clock)
    lazy var scroll: NSScrollView = {
        let view = NSScrollView()
        view.drawsBackground = false
        view.contentView.drawsBackground = false
        view.hasHorizontalScroller = false
        view.hasVerticalScroller = false
        view.documentView = strip
        return view
    }()
    var observer: AXObserver?
    var observedWindow: AXUIElement?
    var observedPID: pid_t = 0
    var windowNumber: Int?
    var windowBounds: CGRect?
    // When the window was last matched on screen or confirmed off screen.
    var lastSeen: TimeInterval = 0
    var lastHeartbeat: TimeInterval = 0
    var heartbeatTitle = ""
    var focused: Bool?
    // What the last refresh placed, so live following can lay out again without Accessibility reads.
    var snapshot: Snapshot?
    var handlers: TabStrip.Handlers?
    var shownClock = ""
    var dragOrigin: (mouse: CGPoint, position: CGPoint)?
    static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
    let formatter = WindowOverlay.formatter("h:mm a")
    let wideFormatter = WindowOverlay.formatter("EEE h:mm a")
    let dateFormatter = WindowOverlay.formatter("EEE MMM d")

    // Moves visible panels to their focus level at once, ahead of the slower Accessibility refresh.
    func setFocused(_ focused: Bool) {
        guard self.focused != focused, let number = windowNumber else { return }
        self.focused = focused
        for panel in [tabsPanel, clockPanel] where panel.isVisible { panel.show(above: number, focused: focused, order: []) }
    }

    func write(_ reply: Reply, name: String) {
        guard let data = try? JSONEncoder().encode(reply) else { return }
        try? data.write(to: stateDirectory.appendingPathComponent(name), options: .atomic)
    }

    func hide() {
        hideBadges()
    }

    func hideBadges() {
        strip.resetPointer()
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
        let callback: AXObserverCallback = { _, _, notification, context in
            guard let context else { return }
            let name = notification as String
            Unmanaged<WindowOverlay>.fromOpaque(context).takeUnretainedValue()
                .onChange(name == kAXMovedNotification || name == kAXResizedNotification)
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

    // An unreadable focus state (nil) keeps the previous stacking level.
    func refresh(snapshot: Snapshot, window: AXUIElement, frame: CGRect, pid: pid_t, number: Int, focused: Bool?, order: [Int]) {
        guard attribute(window, "AXFullScreen") as? Bool != true,
              attribute(window, kAXMinimizedAttribute) as? Bool != true
        else { hide(); return }
        let focused = focused ?? (self.focused == true)
        self.focused = focused
        lastSeen = Date().timeIntervalSince1970
        observe(pid: pid, window: window)
        self.snapshot = snapshot
        let raise = {
            _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            NSRunningApplication(processIdentifier: pid)?.activate()
        }
        // Every request first raises the window so WezTerm's prompts and confirmations are visible.
        let send: (Int?, String?, Int?) -> Void = { [weak self] id, action, index in
            raise()
            self?.write(Reply(title: snapshot.title, updated: Date().timeIntervalSince1970, tab_id: id, action: action, index: index),
                        name: "activate-\(snapshot.key).json")
        }
        handlers = TabStrip.Handlers(
            activate: { send($0.id, nil, nil) },
            close: { send($0.id, "close_tab", nil) },
            move: { send($0.id, "move_tab", $1) },
            action: { send($0.id, $1, nil) },
            newTab: { send(nil, "new_tab", nil) })
        clockBadge.onClick = raise
        clockBadge.onDoubleClick = { [weak self] in self?.resetWindow(window, raise: raise) }
        clockBadge.onWindowDrag = { [weak self] phase, mouse in self?.dragWindow(phase, mouse, window: window, raise: raise) }
        guard let (_, clockFrame) = place(frame: frame) else { hideBadges(); return }
        tabsPanel.show(above: number, focused: focused, order: order)
        if clockFrame != nil { clockPanel.show(above: number, focused: focused, order: order) } else { clockPanel.orderOut(nil) }
        heartbeat(snapshot.title)
    }

    // Lays the strip and clock over a window frame (bottom-left origin); nil when there is no room above it.
    @discardableResult
    func place(frame: CGRect) -> (CGRect, CGRect?)? {
        guard let snapshot, let handlers,
              let screen = NSScreen.screens.max(by: { $0.frame.intersection(frame).area < $1.frame.intersection(frame).area })
        else { return nil }
        // Prefer named tabs; fall back to numbers when labels would crowd out the clock.
        let wide = frame.width >= 900
        let clockWidth: CGFloat = wide ? 116 : 88
        var compact = false
        var width = TabStrip.totalWidth(TabStrip.widths(snapshot.tabs, compact: false))
        var placed = placement(frame: frame, visible: screen.visibleFrame, tabWidth: width, clockWidth: clockWidth)
        if placed?.1 == nil {
            compact = true
            width = TabStrip.totalWidth(TabStrip.widths(snapshot.tabs, compact: true))
            placed = placement(frame: frame, visible: screen.visibleFrame, tabWidth: width, clockWidth: clockWidth)
        }
        guard let (tabFrame, clockFrame) = placed else { return nil }
        strip.update(tabs: snapshot.tabs, compact: compact, handlers: handlers)
        if tabsPanel.contentView !== scroll { tabsPanel.contentView = scroll }
        if tabsPanel.frame != tabFrame { tabsPanel.setFrame(tabFrame, display: true) }
        if let clockFrame {
            let now = Date()
            // Hovering shows the date, except mid-drag where the time stays put.
            let date = clockPanel.frame.contains(NSEvent.mouseLocation) && dragOrigin == nil
            let text = date ? dateFormatter.string(from: now) : (wide ? wideFormatter : formatter).string(from: now)
            let colonVisible = Calendar.current.component(.second, from: now) % 2 == 0
            if shownClock != "\(text)\(colonVisible)" {
                shownClock = "\(text)\(colonVisible)"
                clockBadge.setClock(text, colonVisible: colonVisible)
            }
            if clockPanel.contentView !== clockBadge { clockPanel.contentView = clockBadge }
            if clockPanel.frame != clockFrame { clockPanel.setFrame(clockFrame, display: true) }
        } else { clockPanel.orderOut(nil) }
        return placed
    }

    // Keeps the panels on a window the system is moving or resizing, from its live CoreGraphics bounds.
    func follow(_ bounds: CGRect) {
        windowBounds = bounds
        lastSeen = Date().timeIntervalSince1970
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let frame = CGRect(x: bounds.minX, y: top - bounds.maxY, width: bounds.width, height: bounds.height)
        // Without room above the window, fall back to native tabs at once rather than leaving WezTerm unsure.
        guard let number = windowNumber, let snapshot, let (_, clockFrame) = place(frame: frame) else { hideBadges(); return }
        if heartbeatTitle.isEmpty { heartbeat(snapshot.title) }
        let focused = self.focused == true
        if !tabsPanel.isVisible { tabsPanel.show(above: number, focused: focused, order: []) }
        if clockFrame != nil && !clockPanel.isVisible { clockPanel.show(above: number, focused: focused, order: []) }
    }

    // Double-clicking the clock restores the launch size, centered on the window's current screen.
    func resetWindow(_ window: AXUIElement, raise: () -> Void) {
        guard let current = windowBounds, let top = NSScreen.screens.first?.frame.maxY else { return }
        let frame = CGRect(x: current.minX, y: top - current.maxY, width: current.width, height: current.height)
        guard let screen = NSScreen.screens.max(by: { $0.frame.intersection(frame).area < $1.frame.intersection(frame).area })
        else { return }
        var target = launchBounds(screen: screen.frame, top: top)
        var size = target.size, origin = target.origin
        // Resize first so the window never extends past the screen edge while it moves.
        guard let sizeValue = AXValueCreate(.cgSize, &size), let originValue = AXValueCreate(.cgPoint, &origin),
              AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue) == .success,
              AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, originValue) == .success else { return }
        raise()
        target.origin = origin
        follow(target)
        onChange(true)
    }

    // Dragging the clock moves its window through Accessibility; the panels move in the same step.
    func dragWindow(_ phase: DragPhase, _ mouse: CGPoint, window: AXUIElement, raise: () -> Void) {
        switch phase {
        case .began:
            var position = CGPoint.zero
            guard let value = attribute(window, kAXPositionAttribute), CFGetTypeID(value) == AXValueGetTypeID(),
                  AXValueGetValue(unsafeBitCast(value, to: AXValue.self), .cgPoint, &position) else { return }
            // A busy WezTerm must not stall the pointer for the default six-second timeout.
            AXUIElementSetMessagingTimeout(window, 0.1)
            dragOrigin = (mouse, position)
            raise()
        case .moved:
            guard let (start, position) = dragOrigin else { return }
            // AX positions use a top-left origin, so a pointer moving up moves the window's y down.
            var point = CGPoint(x: (position.x + mouse.x - start.x).rounded(), y: (position.y - mouse.y + start.y).rounded())
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
                point = clampedDragPosition(point, visible: screen.visibleFrame)
            }
            guard let value = AXValueCreate(.cgPoint, &point),
                  AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success else { return }
            if let size = windowBounds?.size { follow(CGRect(origin: point, size: size)) }
            onChange(true)
        case .ended:
            dragOrigin = nil
            onChange(true)
        }
    }

    func heartbeat(_ title: String) {
        let now = Date().timeIntervalSince1970
        guard heartbeatTitle != title || now - lastHeartbeat >= 0.5 else { return }
        heartbeatTitle = title
        lastHeartbeat = now
        write(Reply(title: title, updated: now, tab_id: nil), name: "ready-\(key).json")
    }

    // Hide the panels of an off-screen window but keep acknowledging it, so WezTerm does not
    // switch to native tabs that would flash on return. Windows that already fell back stay native.
    func park() {
        lastSeen = Date().timeIntervalSince1970
        strip.resetPointer()
        // Panels on another Space are already out of sight there and slide back in with their window.
        for panel in [tabsPanel, clockPanel] where panel.isOnActiveSpace { panel.orderOut(nil) }
        if !heartbeatTitle.isEmpty { heartbeat(heartbeatTitle) }
    }
}

// Section: Application lifecycle and snapshot reconciliation

// Separate state and panels for each window, including windows of other GUI
// processes. Match only owner PID and geometry, without reading screen content.
final class Companion: NSObject, NSApplicationDelegate {
    var overlays: [String: WindowOverlay] = [:]
    var timer: Timer?
    var stateWatcher: DispatchSourceFileSystemObject?
    var motionTimer: Timer?
    var refreshing = false
    var followLink: CADisplayLink?
    var followUntil = Date.distantPast
    var dragMonitor: Any?
    var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        stateWatcher = watchDirectory(stateDirectory) { [weak self] in self?.refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(workspaceChanged), name: name, object: nil)
        }
        // Native title-bar drags and edge resizes start live following before AX reports any move.
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
            if self?.overlays.values.contains(where: { $0.observedPID == front }) == true { self?.follow() }
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            let height = NSScreen.screens.first?.frame.maxY ?? 0
            let mouse = NSEvent.mouseLocation
            let point = CGPoint(x: mouse.x, y: height - mouse.y)
            self?.promote { bounds, _ in bounds.contains(point) }
        }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) { overlays.removeAll() }

    // Clicking the wallpaper activates Finder, then Show Desktop slides windows away without AX notice.
    // Check on-screen bounds every frame meanwhile so the badges hide as soon as the slide starts.
    @objc func workspaceChanged(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            promote { _, pid in pid == app.processIdentifier }
        }
        refresh()
        motionTimer?.invalidate()
        let until = Date().addingTimeInterval(motionWatchSeconds)
        motionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self, Date() < until else { timer.invalidate(); return }
            self.parkDisplaced()
        }
    }

    // A clicked or activated window rises before AX reports focus, which can time out meanwhile;
    // raise its panels now so the window never covers them.
    func promote(where matches: (CGRect, Int) -> Bool) {
        let own = Int(ProcessInfo.processInfo.processIdentifier)
        let visible = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let bounds = windowBounds(visible)
        guard let front = visible.first(where: { info in
                  guard let number = info[kCGWindowNumber as String] as? Int, let rect = bounds[number],
                        let pid = info[kCGWindowOwnerPID as String] as? Int, pid != own,
                        (info[kCGWindowLayer as String] as? Int) == 0 else { return false }
                  return matches(rect, pid)
              })?[kCGWindowNumber as String] as? Int,
              let target = overlays.values.first(where: { $0.windowNumber == front }) else { return }
        for overlay in overlays.values where overlay !== target { overlay.setFocused(false) }
        target.setFocused(true)
    }

    func parkDisplaced() {
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let bounds = windowBounds(CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? [])
        // A frontmost WezTerm window that moves is being dragged, which AX notifications already follow.
        for overlay in overlays.values where overlay.observedPID != frontPID && overlay.tabsPanel.isVisible {
            if let number = overlay.windowNumber, displaced(overlay.windowBounds, bounds[number]) { overlay.park() }
        }
    }

    // Section: Live following during moves and resizes
    // AX reports moves late and sparsely, so read the window's on-screen bounds every display frame instead.
    func follow() {
        followUntil = Date().addingTimeInterval(followSeconds)
        guard followLink == nil, let link = NSScreen.main?.displayLink(target: self, selector: #selector(followFrame)) else { return }
        link.add(to: .main, forMode: .common)
        followLink = link
    }

    @objc func followFrame(_ link: CADisplayLink) {
        let now = Date()
        // Only the frontmost app's windows are dragged; others that move were displaced by the system.
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        for overlay in overlays.values where overlay.observedPID == frontPID {
            guard let number = overlay.windowNumber,
                  let bounds = windowBounds(CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(number))
                      as? [[String: Any]] ?? [])[number],
                  bounds != overlay.windowBounds else { continue }
            overlay.follow(bounds)
            followUntil = now.addingTimeInterval(followSeconds)
        }
        // A held button keeps watching, since a drag can pause without ending.
        if NSEvent.pressedMouseButtons & 1 != 0 { followUntil = max(followUntil, now.addingTimeInterval(followSeconds)) }
        guard now >= followUntil else { return }
        link.invalidate()
        followLink = nil
        refresh()
    }

    @objc func refresh() {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        let identifiers = ["org.wezfurlong.wezterm", "com.github.wez.wezterm"]
        guard AXIsProcessTrusted() else {
            for overlay in overlays.values { overlay.hide() }
            return
        }
        // Overlays stay attached while another app is frontmost, avoiding a native-tab flicker on every app switch.
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let now = Date().timeIntervalSince1970
        let files = (try? FileManager.default.contentsOfDirectory(at: stateDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        var snapshots: [String: Snapshot] = [:]
        for file in files where file.lastPathComponent.hasPrefix("window-") && file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file), data.count <= maximumSnapshotBytes,
                  let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
                  validSnapshot(snapshot, filename: file.lastPathComponent, now: snapshot.updated) else { continue }
            if now - snapshot.updated > cleanupAfterSeconds {
                for name in ["window-", "ready-", "activate-"] {
                    try? FileManager.default.removeItem(at: stateDirectory.appendingPathComponent("\(name)\(snapshot.key).json"))
                }
                continue
            }
            if validSnapshot(snapshot, filename: file.lastPathComponent, now: now) { snapshots[snapshot.title] = snapshot }
        }
        let visible = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let order = visible.compactMap { $0[kCGWindowNumber as String] as? Int }
        let bounds = windowBounds(visible)
        var live = Set<String>()
        // Processes whose AX reads timed out, as WezTerm's often do while focus changes.
        var unreadable = Set<pid_t>()
        for app in NSWorkspace.shared.runningApplications where identifiers.contains(app.bundleIdentifier ?? "") {
            let pid = app.processIdentifier
            let application = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(application, 0.1)
            guard let windows = attribute(application, kAXWindowsAttribute) as? [AXUIElement] else {
                unreadable.insert(pid)
                continue
            }
            let focusedWindow = attribute(application, kAXFocusedWindowAttribute)
            let candidates = visible.compactMap { info -> (Int, CGRect)? in
                guard (info[kCGWindowOwnerPID as String] as? Int) == Int(pid), (info[kCGWindowLayer as String] as? Int) == 0,
                      let number = info[kCGWindowNumber as String] as? Int, let rect = bounds[number] else { return nil }
                return (number, rect)
            }
            var claimed = Set<Int>()
            for window in windows {
                guard let title = attribute(window, kAXTitleAttribute) as? String else { unreadable.insert(pid); continue }
                guard let frame = windowFrame(window) else { unreadable.insert(pid); continue }
                // Both lists run front to back, so same-sized windows stacked exactly claim distinct numbers in order.
                // A readable window whose on-screen bounds differ was moved by the system and parks below.
                guard let number = matchWindow(frame: frame, candidates: candidates, claimed: claimed) else { continue }
                claimed.insert(number)
                guard let snapshot = snapshots[title] else { continue }
                live.insert(snapshot.key)
                let overlay = overlays[snapshot.key] ?? WindowOverlay(key: snapshot.key) { [weak self] moved in
                    if moved { self?.follow() } else { self?.refresh() }
                }
                overlays[snapshot.key] = overlay
                overlay.windowNumber = number
                overlay.windowBounds = bounds[number]
                let focused = pid == frontPID ? focusedWindow.map { CFEqual($0, window) } : false
                overlay.refresh(snapshot: snapshot, window: window, frame: frame, pid: pid,
                    number: number, focused: focused, order: order)
            }
        }
        // Mid-gesture, AX frames lag the on-screen bounds; live following owns those overlays until it settles.
        guard overlays.count > live.count, followLink == nil else { return }
        // Unlike the on-screen list, this includes windows on other Spaces, hidden, or minimized.
        let existing = Set((CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? [])
            .compactMap { $0[kCGWindowNumber as String] as? Int })
        let fresh = Set(snapshots.values.map { $0.key })
        for (key, overlay) in overlays where !live.contains(key) {
            let current = overlay.windowNumber.flatMap { bounds[$0] }
            switch overlayFate(fresh: fresh.contains(key), exists: overlay.windowNumber.map(existing.contains) ?? false,
                               onScreen: current != nil, moved: displaced(overlay.windowBounds, current),
                               unreadable: unreadable.contains(overlay.observedPID), unseenFor: now - overlay.lastSeen) {
            case .keep: break
            case .park: overlay.park()
            case .remove: overlays.removeValue(forKey: key)
            }
        }
    }
}

extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

// Section: Diagnostic modes and app entry point
if CommandLine.arguments.contains("--render-strip") {
    // Draws sample tabs (without the live blur behind them) to inspect layout and typography.
    _ = NSApplication.shared
    let tabs = [Tab(id: 1, index: 0, active: true, label: "nvim", branch: "main", progress: 65, progress_state: "normal"),
                Tab(id: 2, index: 1, active: false, label: "my-project", branch: "feature/x"),
                Tab(id: 3, index: 2, active: false, label: "claude", alert: true),
                Tab(id: 4, index: 3, active: false, label: "build", progress_state: "indeterminate"),
                Tab(id: 5, index: 4, active: false, label: "tests", progress: 40, progress_state: "error"),
                Tab(id: 6, index: 5, active: false)]
    let strip = TabStrip()
    strip.update(tabs: tabs, compact: false, handlers: TabStrip.Handlers(
        activate: { _ in }, close: { _ in }, move: { _, _ in }, action: { _, _ in }, newTab: {}))
    strip.badge(for: 2)?.setHovered(true)
    let clock = Badge(kind: .clock)
    clock.setClock("Sun 1:03 AM", colonVisible: true)
    let host = NSView(frame: NSRect(x: 0, y: 0, width: max(strip.frame.width, 130) + 130, height: panelHeight * 2))
    host.wantsLayer = true
    host.layer?.backgroundColor = dark.cgColor
    strip.frame.origin = CGPoint(x: 0, y: panelHeight)
    clock.frame = CGRect(x: strip.frame.width + 8, y: panelHeight, width: 116, height: panelHeight)
    host.addSubview(strip)
    host.addSubview(clock)
    // Show a real window so the layers and blur render as they will on screen.
    let offscreen = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
    offscreen.backgroundColor = dark
    offscreen.contentView = host
    offscreen.setFrameOrigin(NSPoint(x: 40, y: 200))
    offscreen.orderFrontRegardless()
    RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    // Keep the sample window up long enough for `screencapture -l <number>` to photograph it.
    print(offscreen.windowNumber)
    fflush(stdout)
    RunLoop.current.run(until: Date().addingTimeInterval(4))
} else if let argument = CommandLine.arguments.firstIndex(of: "--test") {
    try testSnapshotContract(CommandLine.arguments[argument + 1])
    var plain = BadgeModel(number: "1")
    precondition(Badge.width(plain) == 28, "Numbers alone stay compact")
    plain.number = "12"
    precondition(Badge.width(plain) == 34, "Two-digit numbers widen the pill")
    var named = BadgeModel(number: "1")
    named.label = "nvim"
    named.compact = false
    let labeled = Badge.width(named)
    precondition(labeled > 70, "Labels make room for the name and close slot")
    named.branch = "main"
    precondition(Badge.width(named) > labeled + 20, "A branch widens the pill")
    named.compact = true
    precondition(Badge.width(named) == 28, "Compact pills drop names and branches")
    // Dragging the first of three tabs past the last one's midpoint must request a move to index 2.
    _ = NSApplication.shared
    var moves: [(Int, Int)] = []
    let strip = TabStrip()
    let three = (0..<3).map { Tab(id: $0 + 10, index: $0, active: $0 == 0) }
    let handlers = TabStrip.Handlers(activate: { _ in }, close: { _ in }, move: { moves.append(($0.id, $1)) },
                                     action: { _, _ in }, newTab: {})
    strip.update(tabs: three, compact: true, handlers: handlers)
    strip.drag(10, .began, 0)
    strip.drag(10, .moved, 70)
    strip.drag(10, .ended, 0)
    precondition(moves.count == 1 && moves[0] == (10, 2), "Dragging past the last tab must move it to index 2")
    strip.update(tabs: three, compact: true, handlers: handlers)
    moves.removeAll()
    strip.drag(11, .began, 0)
    strip.drag(11, .moved, 3)
    strip.drag(11, .ended, 0)
    precondition(moves.isEmpty || moves[0].1 != 1, "Dropping a tab where it started must not request a move")
    // A drag that ends in the same slot must still release the pill back to it.
    strip.drag(12, .began, 0)
    strip.drag(12, .moved, 20)
    precondition(strip.badge(for: 12)!.frame.minX == 20, "A dragged pill follows the pointer")
    strip.drag(12, .ended, 0)
    precondition(strip.slotTarget(12) != nil && strip.slotTarget(12)!.minX != 20, "A short drag must snap the pill back to its slot")
    // A wide second tab dragged past the left edge must still move ahead of a narrow first tab.
    let mixed = [Tab(id: 20, index: 0, active: true), Tab(id: 21, index: 1, active: false, label: "a-much-longer-label")]
    strip.update(tabs: mixed, compact: false, handlers: handlers)
    moves.removeAll()
    strip.drag(21, .began, 0)
    strip.drag(21, .moved, -40)
    strip.drag(21, .ended, 0)
    precondition(moves.count == 1 && moves[0] == (21, 0), "A wide tab must be able to move in front of a narrow one")
    // Snapshots listed out of index order still display by index.
    let shuffled = [Tab(id: 32, index: 2, active: false), Tab(id: 30, index: 0, active: true), Tab(id: 31, index: 1, active: false)]
    strip.update(tabs: shuffled, compact: true, handlers: handlers)
    precondition(strip.slotTarget(30)!.minX < strip.slotTarget(31)!.minX && strip.slotTarget(31)!.minX < strip.slotTarget(32)!.minX,
                 "Tabs must display in index order")
    // A neighbor closing mid-drag must not crash or request an index past the end.
    moves.removeAll()
    strip.drag(30, .began, 0)
    strip.drag(30, .moved, 200)
    strip.update(tabs: [Tab(id: 30, index: 0, active: true), Tab(id: 31, index: 1, active: false)], compact: true, handlers: handlers)
    strip.drag(30, .ended, 0)
    precondition(moves.count == 1 && moves[0] == (30, 1), "A drop past a closed tab must clamp to the last index")
    // The dragged tab closing mid-drag must release the strip so later snapshots lay out again.
    let pair = [Tab(id: 40, index: 0, active: true), Tab(id: 41, index: 1, active: false)]
    strip.update(tabs: pair, compact: true, handlers: handlers)
    strip.drag(41, .began, 0)
    strip.drag(41, .moved, 3)
    strip.update(tabs: [Tab(id: 40, index: 0, active: true)], compact: true, handlers: handlers)
    strip.update(tabs: pair, compact: true, handlers: handlers)
    precondition(strip.slotTarget(41)!.minX > strip.slotTarget(40)!.minX, "A drag of a closed tab must not freeze the layout")
    // Hiding the panel mid-drag abandons the gesture, and a late release requests nothing.
    moves.removeAll()
    strip.drag(40, .began, 0)
    strip.drag(40, .moved, 200)
    strip.resetPointer()
    strip.drag(40, .ended, 0)
    precondition(moves.isEmpty && strip.slotTarget(40)!.minX == TabStrip.margin, "A cancelled drag must not move the tab")
    // Releasing outside a pill cancels its click.
    var clicks = 0
    let button = Badge(kind: .plus)
    button.frame = CGRect(x: 0, y: 0, width: 28, height: panelHeight)
    button.onClick = { clicks += 1 }
    for x in [10.0, 80.0] {
        let point = NSPoint(x: x, y: 10)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: 0,
                                           context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            if type == .leftMouseDown { button.mouseDown(with: event) } else { button.mouseUp(with: event) }
        }
    }
    precondition(clicks == 1, "Only a release inside the pill clicks it")
    // Dragging the clock reports a full window-drag gesture instead of a click.
    var phases: [DragPhase] = []
    let clockButton = Badge(kind: .clock)
    clockButton.frame = CGRect(x: 0, y: 0, width: 88, height: panelHeight)
    clockButton.onClick = { clicks += 1 }
    clockButton.onWindowDrag = { phase, _ in phases.append(phase) }
    for type in [NSEvent.EventType.leftMouseDown, .leftMouseDragged, .leftMouseDragged, .leftMouseUp] {
        let event = NSEvent.mouseEvent(with: type, location: NSPoint(x: 10, y: 10), modifierFlags: [], timestamp: 0, windowNumber: 0,
                                       context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        switch type {
        case .leftMouseDown: clockButton.mouseDown(with: event)
        case .leftMouseDragged: clockButton.mouseDragged(with: event)
        default: clockButton.mouseUp(with: event)
        }
    }
    precondition(phases == [.began, .moved, .moved, .ended] && clicks == 1, "Dragging the clock moves the window without clicking")
    // A double click resets the window instead of clicking twice.
    var resets = 0
    clockButton.onDoubleClick = { resets += 1 }
    for count in [1, 2] {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(with: type, location: NSPoint(x: 10, y: 10), modifierFlags: [], timestamp: 0, windowNumber: 0,
                                           context: nil, eventNumber: 0, clickCount: count, pressure: 1)!
            if type == .leftMouseDown { clockButton.mouseDown(with: event) } else { clockButton.mouseUp(with: event) }
        }
    }
    precondition(clicks == 2 && resets == 1, "Double-clicking the clock resets the window once")
    // Clock drags stop with the strip just below the menu bar and leave lower positions alone.
    let menuBar = CGRect(x: 0, y: 0, width: 1800, height: 1136)
    precondition(clampedDragPosition(CGPoint(x: 40, y: 0), visible: menuBar, top: 1169) == CGPoint(x: 40, y: 33 + panelHeight / 2),
                 "Clock drags cannot push the strip under the menu bar")
    precondition(clampedDragPosition(CGPoint(x: 40, y: 200), visible: menuBar, top: 1169).y == 200, "Lower drags are unchanged")
    let clamped = clampedDragPosition(CGPoint(x: 40, y: 0), visible: menuBar, top: 1169)
    let docked = CGRect(x: 40, y: 1169 - clamped.y - 600, width: 900, height: 600)
    precondition(placement(frame: docked, visible: menuBar, tabWidth: 92) != nil, "A window clamped by a clock drag keeps its strip")
    // Launch bounds match config/geometry.lua and center on secondary screens too.
    let launch = launchBounds(screen: CGRect(x: 0, y: 0, width: 1800, height: 1169), top: 1169)
    precondition(launch == CGRect(x: 54, y: 70, width: 1692, height: 1028), "Launch bounds are 94% by 88%, centered")
    let side = launchBounds(screen: CGRect(x: 1800, y: 200, width: 1000, height: 800), top: 1169)
    precondition(side.minX == 1830 && side.minY == 1169 - 1000 + 48, "Launch bounds center on the window's own screen")
    // Exactly stacked same-sized windows must map to distinct CoreGraphics windows.
    let stacked = [(7, CGRect(x: 10, y: 20, width: 800, height: 600)), (8, CGRect(x: 10, y: 20, width: 800, height: 600))]
    let axFrame = CGRect(x: 10, y: 1000 - 20 - 600, width: 800, height: 600)
    let first = matchWindow(frame: axFrame, candidates: stacked, claimed: [], top: 1000)
    precondition(first == 7 && matchWindow(frame: axFrame, candidates: stacked, claimed: [7], top: 1000) == 8,
                 "Stacked windows must claim distinct numbers")
    precondition(matchWindow(frame: axFrame.offsetBy(dx: 50, dy: 0), candidates: stacked, claimed: [], top: 1000) == nil,
                 "Displaced windows must not match")
    precondition(TabStrip.totalWidth([28, 28]) == 28 * 2 + 8 + 28 + TabStrip.margin * 2, "Strip width includes gaps, plus, and margins")
    let wideClock = placement(frame: CGRect(x: 0, y: 60, width: 1421, height: 864), visible: CGRect(x: 0, y: 0, width: 1512, height: 944),
                              tabWidth: 92, clockWidth: 116)!
    precondition(wideClock.1!.width == 116 && wideClock.1!.midX == 710.5, "Wide clocks stay centered")
    precondition(needsOrdering(panel: 2, parent: 1, order: [1, 2]), "Click-raised window needs its normal-level panel restored")
    precondition(!needsOrdering(panel: 2, parent: 1, order: [3, 2, 1]), "Correctly stacked background panels must not be reordered")
    precondition(needsOrdering(panel: 2, parent: 1, order: [1]), "Hidden panels must be restored")
    precondition(overlayFate(fresh: true, exists: true, onScreen: true, moved: false, unreadable: true, unseenFor: 0.3) == .keep,
                 "A brief AX timeout must keep a visible window's overlay up")
    precondition(overlayFate(fresh: true, exists: true, onScreen: true, moved: false, unreadable: true, unseenFor: 5) == .remove,
                 "A lasting AX failure falls back to native tabs")
    precondition(overlayFate(fresh: true, exists: true, onScreen: false, moved: false, unreadable: false, unseenFor: 60) == .park,
                 "A window on another Space parks its overlay")
    precondition(overlayFate(fresh: true, exists: true, onScreen: true, moved: true, unreadable: true, unseenFor: 0) == .park,
                 "A window that Show Desktop slides away parks even while AX times out")
    precondition(overlayFate(fresh: true, exists: true, onScreen: true, moved: false, unreadable: false, unseenFor: 0) == .park,
                 "A readable window that AX no longer matches parks")
    precondition(overlayFate(fresh: false, exists: true, onScreen: false, moved: false, unreadable: false, unseenFor: 0) == .remove,
                 "Expired snapshots remove overlays")
    precondition(overlayFate(fresh: true, exists: false, onScreen: false, moved: false, unreadable: true, unseenFor: 0) == .remove,
                 "Closed windows remove overlays")
    let matched = CGRect(x: 54, y: 70, width: 1692, height: 1029)
    precondition(!displaced(matched, matched.offsetBy(dx: 1, dy: 0)) && !displaced(matched, nil),
                 "Sub-point jitter and off-screen windows are not displacement")
    precondition(displaced(matched, matched.offsetBy(dx: 0, dy: -112)), "Show Desktop's slide is displacement")
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
