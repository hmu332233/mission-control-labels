import AppKit
import ApplicationServices
import MissionControlLabelsCore

/// 썸네일을 실제 창(CG)·앱(NSRunningApplication)·원래 제목(앱 AX 창)에 연결
final class WindowResolver {
    struct AppWindowInfo {
        var title: String
        var frame: CGRect?
    }

    var matcher = GeometryMatcher()
    private let excludedPIDs: Set<pid_t>
    private var appNameCache: [pid_t: String] = [:]
    private var appWindowsCache: [pid_t: [AppWindowInfo]] = [:]

    private(set) var lastWindows: [WindowRecord] = []

    init(excludedPIDs: Set<pid_t>) {
        self.excludedPIDs = excludedPIDs
    }

    /// 세션 또는 창 집합 변경 시 창 캐시 폐기. 앱 이름 캐시는 프로세스 종료 시 정리
    func invalidateSessionCaches() {
        appWindowsCache.removeAll()
        let running = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        appNameCache = appNameCache.filter { running.contains($0.key) }
    }

    func collectWindows(extraExcluded: Set<pid_t> = []) -> [WindowRecord] {
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return [] }
        var out: [WindowRecord] = []
        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  !excludedPIDs.contains(pid), !extraExcluded.contains(pid),
                  let wid = info[kCGWindowNumber as String] as? UInt32,
                  let b = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let w = b["Width"], let h = b["Height"]
            else { continue }
            out.append(WindowRecord(windowID: wid, ownerPID: pid,
                                    frame: CGRect(x: x, y: y, width: w, height: h),
                                    layer: layer,
                                    ownerName: info[kCGWindowOwnerName as String] as? String))
        }
        lastWindows = out
        return out
    }

    func appName(for pid: pid_t) -> String? {
        if let n = appNameCache[pid] { return n }
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        let n = app.localizedName ?? app.bundleIdentifier
        if let n { appNameCache[pid] = n }
        return n
    }

    func bundleID(for pid: pid_t) -> String? {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    func appWindows(for pid: pid_t) -> [AppWindowInfo] {
        if let c = appWindowsCache[pid] { return c }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, MissionControlReader.messagingTimeout)
        let wins = AX.elements(app, kAXWindowsAttribute).map {
            AppWindowInfo(title: AX.string($0, kAXTitleAttribute) ?? "", frame: AX.frame($0))
        }
        appWindowsCache[pid] = wins
        return wins
    }

    struct Outcome {
        var labels: [ResolvedLabel]
        var stats: ResolveStats
        var detail: [(thumbnail: Thumbnail, result: GeometryMatcher.Result, label: ResolvedLabel)]
    }

    func resolve(_ thumbnails: [Thumbnail], dockPID: pid_t?) -> Outcome {
        let start = Date()
        var stats = ResolveStats()
        stats.thumbnailCount = thumbnails.count
        let windows = collectWindows(extraExcluded: dockPID.map { [$0] } ?? [])
        stats.candidateWindowCount = windows.count

        var labels: [ResolvedLabel] = []
        var detail: [(Thumbnail, GeometryMatcher.Result, ResolvedLabel)] = []

        for t in thumbnails {
            let result = matcher.match(t.frame, in: windows)
            var label: ResolvedLabel
            switch result {
            case .unique(let w):
                stats.uniqueMatches += 1
                let (title, resolved) = originalTitle(for: t.title, pid: w.ownerPID)
                if resolved { stats.originalTitleResolved += 1 }
                label = ResolvedLabel(frame: t.frame, appName: appName(for: w.ownerPID), bundleID: bundleID(for: w.ownerPID), title: title, confidence: .geometry)
            case .ambiguous:
                stats.ambiguousMatches += 1
                label = fallbackByTitle(t, windows: windows, stats: &stats)
            case .none:
                stats.unmatched += 1
                label = fallbackByTitle(t, windows: windows, stats: &stats)
            }
            labels.append(label)
            detail.append((t, result, label))
        }
        stats.elapsed = Date().timeIntervalSince(start)
        return Outcome(labels: labels, stats: stats, detail: detail.map { ($0.0, $0.1, $0.2) })
    }

    /// 앱 확정 후, 해당 앱의 AX 창 제목 중 유일하게 대응하는 원래 제목 탐색
    private func originalTitle(for thumbTitle: String, pid: pid_t) -> (String?, Bool) {
        let trimmed = thumbTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, false) }
        let titles = appWindows(for: pid).map(\.title)
        if let i = TitleMatcher.uniqueIndex(thumbnailTitle: trimmed, in: titles) {
            return (titles[i], titles[i] != trimmed)
        }
        return (trimmed, false)
    }

    /// 좌표 대응 실패 시: 화면에 있는 모든 앱의 AX 창 제목 중 정확히 1개만 일치하면 그 앱으로 확정
    private func fallbackByTitle(_ t: Thumbnail, windows: [WindowRecord], stats: inout ResolveStats) -> ResolvedLabel {
        let trimmed = t.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            var all: [(pid: pid_t, title: String)] = []
            for pid in Set(windows.map(\.ownerPID)) {
                for w in appWindows(for: pid) where !w.title.isEmpty { all.append((pid, w.title)) }
            }
            if let i = TitleMatcher.uniqueIndex(thumbnailTitle: trimmed, in: all.map(\.title)) {
                stats.titleUniqueFallbacks += 1
                return ResolvedLabel(frame: t.frame, appName: appName(for: all[i].pid), bundleID: bundleID(for: all[i].pid), title: all[i].title, confidence: .titleUnique)
            }
        }
        return ResolvedLabel(frame: t.frame, appName: nil, title: trimmed.isEmpty ? nil : trimmed, confidence: .thumbnailOnly)
    }
}
