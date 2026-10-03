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
        statusBar.order = overlay.order
        statusBar.onOrderChange = { [weak self] o in self?.overlay.order = o }
        statusBar.showAppIcon = overlay.showAppIcon
        statusBar.onShowAppIconChange = { [weak self] on in self?.overlay.showAppIcon = on }
        statusBar.onToggle = { [weak self] on in on ? self?.engine.start() : self?.engine.stop() }
        statusBar.onArmDiagnostics = { [weak self] in
            self?.engine.diagnostics.arm()
            self?.statusBar.stateText = L10n.string("state.diagnostics.armed", "Diagnostics armed — open Mission Control")
            self?.statusBar.refresh()
        }
        engine.onStateChange = { [weak self] s in
            guard let self else { return }
            let text: String
            switch s {
            case .inactive: text = self.statusBar.isTrusted ? L10n.string("state.inactive", "Inactive") : L10n.string("state.noPermission", "No Permission")
            case .idle: text = L10n.string("state.idle", "Idle")
            case .settling: text = L10n.string("state.settling", "Waiting for layout")
            case .showing: text = L10n.string("state.showing", "Showing")
            }
            self.statusBar.stateText = text
            self.statusBar.refresh()
        }
        engine.onPermissionChange = { [weak self] trusted in
            self?.statusBar.isTrusted = trusted
            self?.statusBar.refresh()
        }
        engine.onDiagnosticWritten = { [weak self] url in
            self?.statusBar.stateText = url.map { L10n.string("state.diagnostics.saved", "Diagnostics saved: %@", $0.lastPathComponent) } ?? L10n.string("state.diagnostics.failed", "Diagnostics failed")
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
