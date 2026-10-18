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
    var onClose: (() -> Void)?
    var onDrag: ((DragPhase, CGFloat) -> Void)?
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
            tint.borderWidth = 0.5
            tint.borderColor = muted.withAlphaComponent(0.5).cgColor
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
    override func mouseEntered(with event: NSEvent) { setHovered(true) }
    override func mouseExited(with event: NSEvent) { setHovered(false) }

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
        if dragging { onDrag?(.ended, 0) } else if pressed { onClick?() }
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
    private var drag: (id: Int, from: Int, drop: Int)?
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
        var ordered = tabs
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
        switch phase {
        case .began:
            drag = (id, from, from)
            addSubview(badge, positioned: .above, relativeTo: nil)
            badge.alphaValue = 0.92
        case .moved:
            guard let current = drag else { return }
            let limit = (targets[-1]?.minX ?? bounds.width) - badge.frame.width - 4
            badge.frame.origin.x = min(max(TabStrip.margin, origin), max(TabStrip.margin, limit))
            let others = shown.filter { $0.id != id }
            var cursor = TabStrip.margin
            var drop = 0
            for width in TabStrip.widths(others, compact: compact) {
                if badge.frame.midX > cursor + width / 2 { drop += 1 }
                cursor += width + 4
            }
            if drop != current.drop {
                drag = (id, current.from, drop)
                var reordered = others
                reordered.insert(shown[current.from], at: drop)
                let layout = slots(reordered)
                for (key, target) in layout where key != id {
                    if let other = key == -1 ? plus : badges[key] { move(other, id: key, to: target) }
                }
            }
        case .ended:
            guard let current = drag else { return }
            var reordered = shown.filter { $0.id != id }
            reordered.insert(shown[current.from], at: current.drop)
            let layout = slots(reordered)
            // The pill was dragged by hand, so its recorded slot is stale: always glide it back into place.
            if let target = layout[id] {
                targets[id] = nil
                move(badge, id: id, to: target)
            }
            badge.alphaValue = 1
            drag = nil
            if current.drop != current.from {
                // Hold the dropped order until WezTerm publishes it, so the strip does not snap back first.
                pendingOrder = reordered.map { $0.id }
                pendingUntil = Date().addingTimeInterval(1.5)
                shown = reordered
                handlers?.move(shown[current.drop], current.drop)
            }
        }
    }
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
    let onChange: () -> Void
    init(key: String, onChange: @escaping () -> Void) { self.key = key; self.onChange = onChange }
    deinit {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        hide()
        for panel in [tabsPanel, clockPanel] { panel.close() }
    }
    let tabsPanel = OverlayPanel()
    let clockPanel: OverlayPanel = {
        // The clock never takes clicks, so it stays transparent to the terminal underneath.
        let panel = OverlayPanel()
        panel.ignoresMouseEvents = true
        return panel
    }()
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
    var lastHeartbeat: TimeInterval = 0
    var heartbeatTitle = ""
    var dimmed: Bool?
    static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
    let formatter = WindowOverlay.formatter("h:mm a")
    let wideFormatter = WindowOverlay.formatter("EEE h:mm a")
    let dateFormatter = WindowOverlay.formatter("EEE MMM d")

    // Overlays of unfocused windows fade back so the focused terminal stays the visual anchor.
    func fade(focused: Bool) {
        guard dimmed != !focused else { return }
        dimmed = !focused
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            for panel in [tabsPanel, clockPanel] { panel.animator().alphaValue = focused ? 1 : 0.62 }
        }
    }

    func write(_ reply: Reply, name: String) {
        guard let data = try? JSONEncoder().encode(reply) else { return }
        try? data.write(to: stateDirectory.appendingPathComponent(name), options: .atomic)
    }

    func hide() {
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
        guard let (tabFrame, clockFrame) = placed else { hideBadges(); return }
        // Every request first raises the window so WezTerm's prompts and confirmations are visible.
        let send: (Int?, String?, Int?) -> Void = { [weak self] id, action, index in
            _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            NSRunningApplication(processIdentifier: pid)?.activate()
            self?.write(Reply(title: snapshot.title, updated: Date().timeIntervalSince1970, tab_id: id, action: action, index: index),
                        name: "activate-\(snapshot.key).json")
        }
        strip.update(tabs: snapshot.tabs, compact: compact, handlers: TabStrip.Handlers(
            activate: { send($0.id, nil, nil) },
            close: { send($0.id, "close_tab", nil) },
            move: { send($0.id, "move_tab", $1) },
            action: { send($0.id, $1, nil) },
            newTab: { send(nil, "new_tab", nil) }))
        if tabsPanel.contentView !== scroll { tabsPanel.contentView = scroll }
        if tabsPanel.frame != tabFrame { tabsPanel.setFrame(tabFrame, display: true) }
        tabsPanel.show(above: number, focused: focused, order: order)
        fade(focused: focused)
        if let clockFrame {
            let seconds = Calendar.current.component(.second, from: Date())
            let date = clockPanel.frame.contains(NSEvent.mouseLocation)
            clockBadge.setClock(date ? dateFormatter.string(from: Date()) : (wide ? wideFormatter : formatter).string(from: Date()),
                                colonVisible: seconds % 2 == 0)
            if clockPanel.contentView !== clockBadge { clockPanel.contentView = clockBadge }
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

// Section: Application lifecycle and snapshot reconciliation

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
                let focused = app.processIdentifier == frontPID
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
    precondition(TabStrip.totalWidth([28, 28]) == 28 * 2 + 8 + 28 + TabStrip.margin * 2, "Strip width includes gaps, plus, and margins")
    let wideClock = placement(frame: CGRect(x: 0, y: 60, width: 1421, height: 864), visible: CGRect(x: 0, y: 0, width: 1512, height: 944),
                              tabWidth: 92, clockWidth: 116)!
    precondition(wideClock.1!.width == 116 && wideClock.1!.midX == 710.5, "Wide clocks stay centered")
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
