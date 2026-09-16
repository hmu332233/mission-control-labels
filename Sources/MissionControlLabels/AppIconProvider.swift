import AppKit

/// pid별 앱 아이콘 캐시. 세션 무효화 시 종료된 프로세스 항목 정리
final class AppIconProvider {
    private var cache: [pid_t: NSImage] = [:]

    func icon(for pid: pid_t) -> NSImage? {
        if let cached = cache[pid] { return cached }
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon else { return nil }
        cache[pid] = icon
        return icon
    }

    func invalidateSessionCaches() {
        let running = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        cache = cache.filter { running.contains($0.key) }
    }
}
