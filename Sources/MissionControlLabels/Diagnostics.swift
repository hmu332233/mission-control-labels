import AppKit
import ApplicationServices
import MissionControlLabelsCore

/// 개발 중 명시적으로 켠 경우에만 창 제목 등 상세 정보를 로컬 파일에 기록한다. 외부 전송 없음.
final class Diagnostics {
    private let lock = NSLock()
    private var armed = false

    var isArmed: Bool { lock.lock(); defer { lock.unlock() }; return armed }
    func arm() { lock.lock(); armed = true; lock.unlock() }
    func disarm() { lock.lock(); armed = false; lock.unlock() }

    static var logDirectory: URL {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Logs/MissionControlLabels", isDirectory: true)
    }

    func write(reader: MissionControlReader, group: AXUIElement, thumbnails: [Thumbnail],
               outcome: WindowResolver.Outcome, windows: [WindowRecord]) -> URL? {
        var s = ""
        let f = ISO8601DateFormatter()
        s += "# MissionControlLabels diagnostic \(f.string(from: Date()))\n"
        s += "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        s += "screens:\n"
        for sc in NSScreen.screens {
            s += "  frame=\(sc.frame) scale=\(sc.backingScaleFactor) name=\(sc.localizedName)\n"
        }
        s += "\n## Dock AX tree (mc group)\n"
        reader.dumpTree(group, into: &s)

        s += "\n## Thumbnails (\(thumbnails.count))\n"
        for (i, t) in thumbnails.enumerated() {
            s += "[\(i)] frame=\(fmt(t.frame)) id=\(t.identifier ?? "-") roleDesc=\(t.roleDescription ?? "-") title=\"\(t.title)\"\n"
        }
        s += "\n## CG windows layer 0 on screen (\(windows.count))\n"
        for w in windows {
            s += "wid=\(w.windowID) pid=\(w.ownerPID) owner=\(w.ownerName ?? "-") frame=\(fmt(w.frame))\n"
        }
        s += "\n## Matching\n"
        for (i, d) in outcome.detail.enumerated() {
            let r: String
            switch d.result {
            case .unique(let w): r = "unique wid=\(w.windowID) pid=\(w.ownerPID)"
            case .ambiguous(let ws): r = "ambiguous wids=\(ws.map(\.windowID))"
            case .none: r = "none"
            }
            s += "[\(i)] \(r) -> app=\"\(d.label.appName ?? "-")\" title=\"\(d.label.title ?? "-")\" conf=\(d.label.confidence.rawValue)\n"
        }
        let st = outcome.stats
        s += "\n## Stats\nthumbnails=\(st.thumbnailCount) candidates=\(st.candidateWindowCount) unique=\(st.uniqueMatches) ambiguous=\(st.ambiguousMatches) unmatched=\(st.unmatched) titleUniqueFallback=\(st.titleUniqueFallbacks) originalTitleResolved=\(st.originalTitleResolved) elapsed=\(String(format: "%.1f", st.elapsed * 1000))ms\n"

        let dir = Self.logDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = f.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = dir.appendingPathComponent("diagnostic-\(stamp).txt")
        do {
            try s.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func fmt(_ r: CGRect) -> String {
        "(\(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))x\(Int(r.height)))"
    }
}
