import AppKit
import MissionControlLabelsCore

/// 키 윈도우 비대상, 마우스 입력 전부 통과시키는 투명 창
final class OverlayWindow: NSWindow {
    init(screenFrame: NSRect) {
        super.init(contentRect: screenFrame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        contentView = NSView(frame: NSRect(origin: .zero, size: screenFrame.size))
        contentView?.wantsLayer = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 화면마다 오버레이 창 1개를 두고 라벨 배치·갱신·제거. 메인 스레드 전용
final class OverlayController {
    /// 모서리 배치 시 썸네일 경계에서 라벨까지의 안쪽 여백(pt)
    static let inset: CGFloat = 8
    static let anchorDefaultsKey = "labelAnchor"
    static let orderDefaultsKey = "labelOrder"
    static let showAppIconDefaultsKey = "showAppIcon"
    static let iconLayoutDefaultsKey = "labelIconLayout"
    static let scaleDefaultsKey = "labelScale"

    var anchor: LabelAnchor = LabelAnchor(rawValue: UserDefaults.standard.string(forKey: OverlayController.anchorDefaultsKey) ?? "") ?? .default {
        didSet {
            UserDefaults.standard.set(anchor.rawValue, forKey: Self.anchorDefaultsKey)
            rerender()
        }
    }

    var order: LabelOrder = LabelOrder(rawValue: UserDefaults.standard.string(forKey: OverlayController.orderDefaultsKey) ?? "") ?? .default {
        didSet {
            UserDefaults.standard.set(order.rawValue, forKey: Self.orderDefaultsKey)
            rerender()
        }
    }

    /// 기본 꺼짐: design/spec.md 시안 A는 아이콘 없는 라벨을 기준으로 함
    var showAppIcon: Bool = UserDefaults.standard.bool(forKey: OverlayController.showAppIconDefaultsKey) {
        didSet {
            UserDefaults.standard.set(showAppIcon, forKey: Self.showAppIconDefaultsKey)
            rerender()
        }
    }

    /// 아이콘을 텍스트 줄 안에 둘지 카드 왼쪽 별도 칸에 둘지
    var iconLayout: LabelIconLayout = LabelIconLayout(rawValue: UserDefaults.standard.string(forKey: OverlayController.iconLayoutDefaultsKey) ?? "") ?? .default {
        didSet {
            UserDefaults.standard.set(iconLayout.rawValue, forKey: Self.iconLayoutDefaultsKey)
            rerender()
        }
    }

    /// 라벨 전체 배율
    var scale: LabelScale = LabelScale(rawValue: UserDefaults.standard.string(forKey: OverlayController.scaleDefaultsKey) ?? "") ?? .default {
        didSet {
            UserDefaults.standard.set(scale.rawValue, forKey: Self.scaleDefaultsKey)
            rerender()
        }
    }

    private var windows: [OverlayWindow] = []
    private var geometry = DisplayGeometry(primaryHeight: 0, screenFrames: [])
    private let sessions: SessionCounter
    private let iconProvider = AppIconProvider()
    private var lastLabels: [ResolvedLabel] = []
    private var lastSession: SessionToken?
    private(set) var isShowing = false

    init(sessions: SessionCounter) {
        self.sessions = sessions
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func screensChanged() {
        // 화면 구성 변경 시 기존 오버레이 전부 정리, 다음 표시 때 재생성
        tearDown()
    }

    private func refreshGeometry() {
        let screens = NSScreen.screens
        let primary = screens.first(where: { $0.frame.origin == .zero }) ?? screens.first
        geometry = DisplayGeometry(primaryHeight: primary?.frame.height ?? 0, screenFrames: screens.map(\.frame))
        if windows.count != screens.count || zip(windows, screens).contains(where: { $0.frame != $1.frame }) {
            tearDown()
            windows = screens.map { OverlayWindow(screenFrame: $0.frame) }
        }
    }

    /// 세션이 현재가 아니면 지연 도착 결과로 간주해 무시
    func show(_ labels: [ResolvedLabel], session: SessionToken) {
        guard sessions.isCurrent(session) else { return }
        lastLabels = labels
        lastSession = session
        refreshGeometry()
        if showAppIcon { iconProvider.invalidateSessionCaches() }
        for w in windows { w.contentView?.subviews.forEach { $0.removeFromSuperview() } }

        // 라벨이 놓일 썸네일(화면 로컬 좌표)과 화면 인덱스
        struct Placement {
            let label: ResolvedLabel
            let screen: Int
            let local: CGRect
        }
        var placements: [Placement] = []
        for label in labels {
            let thumbAppKit = geometry.appKitRect(fromTopLeft: label.frame)
            guard let idx = geometry.screenIndex(forAppKitRect: thumbAppKit), idx < windows.count else { continue }
            placements.append(Placement(label: label, screen: idx,
                                        local: geometry.localRect(thumbAppKit, inScreen: geometry.screenFrames[idx])))
        }

        // 폭 상한은 화면 단위로 한 번에 계산한다. 라벨이 썸네일 밖의 빈 공간까지 쓸 수 있는지,
        // 있다면 어디까지는 같은 화면의 다른 썸네일과 함께 봐야 알 수 있다
        var maxWidths = [CGFloat](repeating: 0, count: placements.count)
        for screen in Set(placements.map(\.screen)) {
            let members = placements.indices.filter { placements[$0].screen == screen }
            let rects = members.map { placements[$0].local }
            let limits = LabelWidthPolicy.maxWidths(rects, screen: geometry.screenFrames[screen].size,
                                                   inset: Self.inset, anchor: anchor)
            for (i, slot) in members.enumerated() { maxWidths[slot] = limits[i] }
        }

        for (index, placement) in placements.enumerated() {
            let window = windows[placement.screen]
            let local = placement.local
            let maxWidth = max(24, maxWidths[index])
            let lineLimit = LabelLayoutPolicy.titleLineLimit(forThumbnailHeight: local.height)
            let icon = (showAppIcon ? placement.label.ownerPID.flatMap(iconProvider.icon(for:)) : nil)
            let view = LabelView(label: placement.label, maxWidth: maxWidth, titleLineLimit: lineLimit,
                                 alignment: anchor.textAlignment, order: order, icon: icon,
                                 iconLayout: iconLayout, scale: scale)
            var size = view.frame.size
            size.height = min(size.height, max(0, local.height - Self.inset * 2))
            let origin = anchor.origin(labelSize: size, in: local, inset: Self.inset)
            view.frame = NSRect(origin: origin, size: size)
            window.contentView?.addSubview(view)
        }
        for w in windows { w.orderFrontRegardless() }
        isShowing = true
    }

    /// 설정을 바꾸면 현재 보이는 라벨을 바로 다시 그린다. Mission Control을 닫지 않고 결과를 확인할 수 있게
    private func rerender() {
        guard isShowing, let session = lastSession else { return }
        show(lastLabels, session: session)
    }

    func hide() {
        for w in windows {
            w.contentView?.subviews.forEach { $0.removeFromSuperview() }
            w.orderOut(nil)
        }
        isShowing = false
    }

    func tearDown() {
        hide()
        for w in windows { w.close() }
        windows.removeAll()
    }

    var overlayWindowCount: Int { windows.count }
}
