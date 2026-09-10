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

    var anchor: LabelAnchor = LabelAnchor(rawValue: UserDefaults.standard.string(forKey: OverlayController.anchorDefaultsKey) ?? "") ?? .default {
        didSet { UserDefaults.standard.set(anchor.rawValue, forKey: Self.anchorDefaultsKey) }
    }

    var order: LabelOrder = LabelOrder(rawValue: UserDefaults.standard.string(forKey: OverlayController.orderDefaultsKey) ?? "") ?? .default {
        didSet { UserDefaults.standard.set(order.rawValue, forKey: Self.orderDefaultsKey) }
    }

    private var windows: [OverlayWindow] = []
    private var geometry = DisplayGeometry(primaryHeight: 0, screenFrames: [])
    private let sessions: SessionCounter
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
        refreshGeometry()
        for w in windows { w.contentView?.subviews.forEach { $0.removeFromSuperview() } }

        for label in labels {
            let thumbAppKit = geometry.appKitRect(fromTopLeft: label.frame)
            guard let idx = geometry.screenIndex(forAppKitRect: thumbAppKit), idx < windows.count else { continue }
            let window = windows[idx]
            let local = geometry.localRect(thumbAppKit, inScreen: geometry.screenFrames[idx])
            let maxWidth = max(24, local.width - Self.inset * 2)
            let lineLimit = LabelLayoutPolicy.titleLineLimit(forThumbnailHeight: local.height)
            let view = LabelView(label: label, maxWidth: maxWidth, titleLineLimit: lineLimit, alignment: anchor.textAlignment, order: order)
            var size = view.frame.size
            size.height = min(size.height, max(0, local.height - Self.inset * 2))
            let origin = anchor.origin(labelSize: size, in: local, inset: Self.inset)
            view.frame = NSRect(origin: origin, size: size)
            window.contentView?.addSubview(view)
        }
        for w in windows { w.orderFrontRegardless() }
        isShowing = true
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
