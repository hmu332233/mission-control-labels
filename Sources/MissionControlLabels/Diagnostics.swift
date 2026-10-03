import AppKit
import ApplicationServices
import MissionControlLabelsCore

/// 개발 중 명시적으로 켠 경우에 한해 창 제목 등 상세 정보를 로컬 파일에 기록. 외부 전송 없음
/// 라벨이 안 나오는 경우를 추적할 수 있게, 성공뿐 아니라 실패(그룹·썸네일 없음)에도 파일을 남긴다
final class Diagnostics {
    private let lock = NSLock()
    private var armed = false
    private var armedAt: Date?

    /// Mission Control 그룹을 찾지 못하면 진단 기록을 남기는 대기 시간(초)
    static let notFoundTimeout: TimeInterval = 15

    var isArmed: Bool { lock.lock(); defer { lock.unlock() }; return armed }
    var armedSeconds: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard let armedAt else { return -1 }
        return Date().timeIntervalSince(armedAt)
    }
    func arm() { lock.lock(); armed = true; armedAt = Date(); lock.unlock() }
    func disarm() { lock.lock(); armed = false; armedAt = nil; lock.unlock() }

    static var logDirectory: URL {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Logs/MissionControlLabels", isDirectory: true)
    }

    /// `outcome`이 없으면(레이아웃 미안정·썸네일 0개) 구조 관찰 결과만 기록. 아무 경우나 파일을 남기므로 메뉴 동작이 침묵하지 않음
    func write(reader: MissionControlReader, groups: [AXUIElement], thumbnails: [Thumbnail],
               outcome: WindowResolver.Outcome?, windows: [WindowRecord]) -> URL? {
        var s = header()
        s += "\n## Mission Control source\n"
        s += "groups found: \(groups.count)\n"
        reader.environmentReport(into: &s)

        s += "\n## Group trees\n"
        for (i, g) in groups.enumerated() {
            s += "[\(i)]\n"
            reader.dumpTree(g, into: &s)
        }

        s += "\n## Thumbnails (\(thumbnails.count))\n"
        for (i, t) in thumbnails.enumerated() {
            s += "[\(i)] frame=\(fmt(t.frame)) id=\(t.identifier ?? "-") roleDesc=\(t.roleDescription ?? "-") title=\"\(t.title)\"\n"
        }

        guard let outcome else {
            s += "\n## Matching\nskipped: 라벨을 그리기 전 단계(레이아웃 미안정 또는 썸네일 없음)에서 기록\n"
            return save(s, prefix: thumbnails.isEmpty ? "no-thumbnails" : "no-layout")
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
        return save(s, prefix: "diagnostic")
    }

    /// Mission Control 그룹 자체가 안 보인 경우의 기록
    func writeNotFound(reader: MissionControlReader) -> URL? {
        var s = header()
        s += "\n## Result\nMission Control 그룹을 \(Int(Self.notFoundTimeout))초 동안 찾지 못함.\n"
        s += "Mission Control을 연 상태에서 이 기록이 생성됐다면 Mission Control을 그리는 프로세스의 Accessibility 구조가 바뀐 것.\n"
        s += "\n## Mission Control source\n"
        reader.environmentReport(into: &s)
        return save(s, prefix: "not-found")
    }

    private func header() -> String {
        let f = ISO8601DateFormatter()
        var s = "# MissionControlLabels diagnostic \(f.string(from: Date()))\n"
        s += "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        s += "screens:\n"
        for sc in NSScreen.screens {
            s += "  frame=\(sc.frame) scale=\(sc.backingScaleFactor) name=\(sc.localizedName)\n"
        }
        return s
    }

    private func save(_ contents: String, prefix: String) -> URL? {
        let dir = Self.logDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = ISO8601DateFormatter()
        let stamp = f.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = dir.appendingPathComponent("\(prefix)-\(stamp).txt")
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func fmt(_ r: CGRect) -> String {
        "(\(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))x\(Int(r.height)))"
    }
}
