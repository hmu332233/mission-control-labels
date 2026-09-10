import AppKit
import MissionControlLabelsCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sessions = SessionCounter()
    private var overlay: OverlayController!
    private var engine: LabelEngine!
    private var statusBar: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = OverlayController(sessions: sessions)
        engine = LabelEngine(sessions: sessions, overlay: overlay)
        statusBar = StatusBarController()

        statusBar.isTrusted = AX.isTrusted()
        if !statusBar.isTrusted { AX.promptForTrust() }

        statusBar.anchor = overlay.anchor
        statusBar.onAnchorChange = { [weak self] a in self?.overlay.anchor = a }
        statusBar.onToggle = { [weak self] on in on ? self?.engine.start() : self?.engine.stop() }
        statusBar.onArmDiagnostics = { [weak self] in
            self?.engine.diagnostics.arm()
            self?.statusBar.stateText = "진단 대기 중 — Mission Control을 열어 주세요"
            self?.statusBar.refresh()
        }
        engine.onStateChange = { [weak self] s in
            guard let self else { return }
            let text: String
            switch s {
            case .inactive: text = self.statusBar.isTrusted ? "비활성" : "권한 없음"
            case .idle: text = "대기"
            case .settling: text = "배치 대기"
            case .showing: text = "표시 중"
            }
            self.statusBar.stateText = text
            self.statusBar.refresh()
        }
        engine.onPermissionChange = { [weak self] trusted in
            self?.statusBar.isTrusted = trusted
            self?.statusBar.refresh()
        }
        engine.onDiagnosticWritten = { [weak self] url in
            self?.statusBar.stateText = url.map { "진단 기록 저장: \($0.lastPathComponent)" } ?? "진단 기록 실패"
            self?.statusBar.refresh()
            if let url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }

        if CommandLine.arguments.contains("--probe") {
            engine.diagnostics.arm()
        }
        engine.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
        overlay.tearDown()
    }
}
