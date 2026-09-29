import AppKit
import ApplicationServices
import MissionControlLabelsCore
import os

/// 상태 전환·수집 주기 담당. 수집은 직렬 큐, 표시는 메인 스레드에서 수행
final class LabelEngine {
    enum State: String { case inactive, idle, settling, showing }

    /// 초기 실험값. 측정 결과로 조정
    static let idleInterval: TimeInterval = 0.25
    static let openInterval: TimeInterval = 0.08
    static let noPermissionInterval: TimeInterval = 1.0
    static let stableObservationsRequired = 2

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
    private var previousSnapshot: [Thumbnail] = []
    private var stableCount = 0
    private var renderedSnapshot: [Thumbnail]?
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
            previousSnapshot = []
            stableCount = 0
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

        let stable = LayoutStability.isStable(previousSnapshot, snapshot)
        stableCount = stable ? stableCount + 1 : 1
        previousSnapshot = snapshot

        if stable && stableCount >= Self.stableObservationsRequired {
            if renderedSnapshot == nil || !LayoutStability.isStable(renderedSnapshot!, snapshot) {
                let session = currentSession
                let outcome = resolver.resolve(snapshot, hostPIDs: reader.hostPIDs)
                let st = outcome.stats
                log.info("resolved thumbnails=\(st.thumbnailCount) unique=\(st.uniqueMatches) ambiguous=\(st.ambiguousMatches) unmatched=\(st.unmatched) titleFallback=\(st.titleUniqueFallbacks) elapsedMs=\(Int(st.elapsed * 1000))")
                renderedSnapshot = snapshot
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
        } else if renderedSnapshot != nil {
            // 배치 변경(Space 이동, 창 재배치). 즉시 숨기고 재안정까지 대기
            renderedSnapshot = nil
            DispatchQueue.main.async { self.overlay.hide() }
            setState(.settling)
        } else {
            setState(.settling)
        }
        schedule(after: Self.openInterval, generation: generation)
    }
}
