import AppKit
import ApplicationServices
import MissionControlLabelsCore
import os

/// 상태 전환·수집 주기 담당. 수집은 직렬 큐, 표시는 메인 스레드에서 수행
final class LabelEngine {
    enum State: String { case inactive, idle, settling, showing }

    /// 측정값 기준. Mission Control이 닫혀 있을 때 조사는 children 한 번 읽는 것뿐이라
    /// 주기을 올려도 부담이 거의 없다
    static let idleInterval: TimeInterval = 0.06
    static let openInterval: TimeInterval = 0.06
    static let noPermissionInterval: TimeInterval = 1.0
    /// 배치가 계속 바뀌는 동안 다시 그리는 최소 간격. resolve에 약 80ms 걸리므로 그보다 자주는 무의미
    static let renderThrottle: TimeInterval = 0.12

    private let log = Logger(subsystem: "com.markhan.MissionControlLabels", category: "engine")
    private let queue = DispatchQueue(label: "com.markhan.MissionControlLabels.collector", qos: .userInitiated)
    private let reader = MissionControlReader()
    private let resolver: WindowResolver
    private let sessions: SessionCounter
    private let overlay: OverlayController
    let diagnostics = Diagnostics()

    // 워커 큐에서만 접근하는 상태
    private var enabled = false
    private var generation = 0
    private var renderedSnapshot: [Thumbnail]?
    private var lastRender = Date.distantPast
    private var wasOpen = false
    private var currentSession: SessionToken

    // 메인에서 읽는 표시용 상태
    private(set) var state: State = .inactive { didSet { onStateChange?(state) } }
    var onStateChange: ((State) -> Void)?
    var onDiagnosticWritten: ((URL?) -> Void)?
    var onPermissionChange: ((Bool) -> Void)?

    init(sessions: SessionCounter, overlay: OverlayController) {
        self.sessions = sessions
        self.overlay = overlay
        self.currentSession = sessions.current
        self.resolver = WindowResolver(excludedPIDs: [ProcessInfo.processInfo.processIdentifier])
    }

    func start() {
        queue.async {
            guard !self.enabled else { return }
            self.enabled = true
            self.generation += 1
            self.tick(generation: self.generation)
        }
    }

    func stop() {
        queue.async {
            self.enabled = false
            self.generation += 1
            self.endSessionIfOpen()
            DispatchQueue.main.async { self.state = .inactive }
        }
    }

    private func setState(_ s: State) {
        DispatchQueue.main.async { if self.state != s { self.state = s } }
    }

    private func schedule(after interval: TimeInterval, generation: Int) {
        queue.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.tick(generation: generation)
        }
    }

    private func endSessionIfOpen() {
        if wasOpen || renderedSnapshot != nil {
            wasOpen = false
            renderedSnapshot = nil
            sessions.advance()
            resolver.invalidateSessionCaches()
            DispatchQueue.main.async { self.overlay.hide() }
        }
    }

    private var lastTrusted: Bool?

    private func tick(generation: Int) {
        guard enabled, generation == self.generation else { return }

        let trusted = AX.isTrusted()
        if lastTrusted != trusted {
            lastTrusted = trusted
            DispatchQueue.main.async { self.onPermissionChange?(trusted) }
        }
        guard trusted else {
            endSessionIfOpen()
            setState(.inactive)
            schedule(after: Self.noPermissionInterval, generation: generation)
            return
        }

        let groups = reader.missionControlGroups()
        if groups.isEmpty {
            if wasOpen { log.debug("mission control closed") }
            endSessionIfOpen()
            setState(.idle)
            // 그룹 자체를 못 찾으면 기록이 한 줄도 안 남는다. 대기 초과 시 실패 기록을 남긴다
            if diagnostics.isArmed, diagnostics.armedSeconds > Diagnostics.notFoundTimeout {
                diagnostics.disarm()
                let url = diagnostics.writeNotFound(reader: reader)
                DispatchQueue.main.async { self.onDiagnosticWritten?(url) }
            }
            schedule(after: Self.idleInterval, generation: generation)
            return
        }

        if !wasOpen {
            wasOpen = true
            currentSession = sessions.advance()
            resolver.invalidateSessionCaches()
            log.debug("mission control opened")
        }

        let snapshot = reader.thumbnails(in: groups)
        // 썸네일이 0개면 안정 판정이 영원히 불가능하다. 이 상태에서 기록해 침묵하는 진단을 없앤다
        if snapshot.isEmpty, diagnostics.isArmed {
            diagnostics.disarm()
            let url = diagnostics.write(reader: reader, groups: groups, thumbnails: [], outcome: nil, windows: [])
            DispatchQueue.main.async { self.onDiagnosticWritten?(url) }
        }
        guard !snapshot.isEmpty else {
            setState(.settling)
            schedule(after: Self.openInterval, generation: generation)
            return
        }

        // Mission Control 여는 애니메이션은 완성된 배치 위에 그려진다: AX는 첫 관측부터 최종
        // 좌표를 돌려준다(측정: 처음 목격한 프레임과 2.5초 뒤 프레임이 완전히 동일).
        // 그래서 안정화를 두 번 기다리는 대신 첫 번째 비어 있지 않은 프레임에서 곧바로 그리고,
        // 배치가 바뀌면 숨기는 것이 아니라 다시 그린다. 숨기면 창을 옮길 때마다 라벨이 깜빡였다
        let changed = renderedSnapshot.map { !LayoutStability.isStable($0, snapshot) } ?? true
        if changed, Date().timeIntervalSince(lastRender) >= Self.renderThrottle {
            render(snapshot, groups: groups)
        }
        schedule(after: Self.openInterval, generation: generation)
    }

    private func render(_ snapshot: [Thumbnail], groups: [AXUIElement]) {
        let session = currentSession
        let outcome = resolver.resolve(snapshot, hostPIDs: reader.hostPIDs)
        let st = outcome.stats
        log.info("resolved thumbnails=\(st.thumbnailCount) unique=\(st.uniqueMatches) ambiguous=\(st.ambiguousMatches) unmatched=\(st.unmatched) titleFallback=\(st.titleUniqueFallbacks) elapsedMs=\(Int(st.elapsed * 1000))")
        renderedSnapshot = snapshot
        lastRender = Date()
        let labels = outcome.labels
        DispatchQueue.main.async {
            self.overlay.show(labels, session: session)
            self.state = .showing
        }
        if diagnostics.isArmed {
            diagnostics.disarm()
            let url = diagnostics.write(reader: reader, groups: groups, thumbnails: snapshot,
                                        outcome: outcome, windows: resolver.lastWindows)
            DispatchQueue.main.async { self.onDiagnosticWritten?(url) }
        }
    }
}
