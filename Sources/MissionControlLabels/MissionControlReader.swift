import AppKit
import ApplicationServices
import MissionControlLabelsCore

/// Mission Control 그룹·창 썸네일 읽기 (Accessibility 트리)
/// macOS 27부터는 Mission Control UI를 WindowManager가 그리고 화면별 `mc.display` 그룹을 노출한다.
/// 그 이전 버전에서는 Dock 단일 `mc` 그룹 아래에 썸네일이 있었다. 순서대로 시도한다.
final class MissionControlReader {
    /// 썸네일을 노출하는 프로세스 우선순위
    static let hostBundleIDs = ["com.apple.WindowManager", "com.apple.dock"]
    /// AX 응답 제한 시간(초)
    static let messagingTimeout: Float = 0.3

    /// Mission Control을 그리는 프로세스들의 PID. 자체 창이 창 후보에 섞이지 않도록 제외
    var hostPIDs: Set<pid_t> {
        Set(NSWorkspace.shared.runningApplications
            .filter { Self.hostBundleIDs.contains($0.bundleIdentifier ?? "") }
            .map(\.processIdentifier))
    }

    /// Mission Control이 열려 있을 때만 존재하는 그룹들.
    /// macOS 27+: 화면마다 `mc.display` 그룹 하나씩. 이전 macOS: Dock의 `mc` 그룹 하나.
    func missionControlGroups() -> [AXUIElement] {
        let hosts = Self.hostBundleIDs.compactMap(application)
        for host in hosts {
            let displays = AX.children(host).filter { AX.string($0, kAXIdentifierAttribute) == "mc.display" }
            if !displays.isEmpty { return displays }
        }
        for host in hosts {
            let children = AX.children(host)
            if let legacy = children.first(where: { AX.string($0, kAXIdentifierAttribute) == "mc" }) { return [legacy] }
            if let legacy = children.first(where: {
                AX.string($0, kAXRoleAttribute) == kAXGroupRole as String
                    && AX.string($0, kAXTitleAttribute) == "Mission Control"
            }) { return [legacy] }
        }
        return []
    }

    /// 썸네일 수집. 상단 Spaces 막대(mc.spaces*) 하위 트리 제외
    func thumbnails(in groups: [AXUIElement]) -> [Thumbnail] {
        var out: [Thumbnail] = []
        for g in groups { collect(g, depth: 0, into: &out) }
        // 연속 관측 비교 안정화를 위해 왼쪽 위부터 읽는 순서로 정렬
        out.sort { a, b in
            if abs(a.frame.minY - b.frame.minY) > 2 { return a.frame.minY < b.frame.minY }
            return a.frame.minX < b.frame.minX
        }
        return out
    }

    /// 진단용: 어떤 프로세스·그룹을 보고 있는지. 트리 변화로 라벨이 안 나올 때 첫 번째로 보는 정보
    func environmentReport(into s: inout String) {
        let hosts = Self.hostBundleIDs.compactMap { bid -> (String, AXUIElement?) in (bid, application(bid)) }
        s += "AX hosts tried:\n"
        for (bid, el) in hosts {
            guard let el else { s += "  \(bid): process not running\n"; continue }
            let children = AX.children(el)
            s += "  \(bid): \(children.count) top-level children\n"
            for c in children {
                let role = AX.string(c, kAXRoleAttribute) ?? "?"
                let id = AX.string(c, kAXIdentifierAttribute) ?? "-"
                let title = AX.string(c, kAXTitleAttribute) ?? "-"
                s += "    \(role) id=\"\(id)\" title=\"\(title)\" children=\(AX.children(c).count)\n"
            }
        }
        if hosts.isEmpty { s += "  none of \(Self.hostBundleIDs) is running\n" }
    }

    /// 진단용 트리 덤프. 개발 중 명시적으로 켠 경우에 한해 호출
    func dumpTree(_ el: AXUIElement, depth: Int = 0, into s: inout String, maxDepth: Int = 10) {
        guard depth <= maxDepth else { return }
        let pad = String(repeating: "  ", count: depth)
        let role = AX.string(el, kAXRoleAttribute) ?? "?"
        let sub = AX.string(el, kAXSubroleAttribute).map { " sub=\($0)" } ?? ""
        let id = AX.string(el, kAXIdentifierAttribute).map { " id=\"\($0)\"" } ?? ""
        let title = AX.string(el, kAXTitleAttribute).map { " title=\"\($0)\"" } ?? ""
        let desc = AX.string(el, kAXDescriptionAttribute).map { " desc=\"\($0)\"" } ?? ""
        let rd = AX.string(el, kAXRoleDescriptionAttribute).map { " roleDesc=\"\($0)\"" } ?? ""
        let fr = AX.frame(el).map { " frame=\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))x\(Int($0.height))" } ?? ""
        s += "\(pad)\(role)\(sub)\(id)\(title)\(desc)\(rd)\(fr)\n"
        for c in AX.children(el) { dumpTree(c, depth: depth + 1, into: &s, maxDepth: maxDepth) }
    }

    // MARK: -

    private func application(_ bundleID: String) -> AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { return nil }
        let el = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(el, Self.messagingTimeout)
        return el
    }

    private func collect(_ el: AXUIElement, depth: Int, into out: inout [Thumbnail]) {
        guard depth < 12 else { return }
        let identifier = AX.string(el, kAXIdentifierAttribute)
        if let identifier, identifier.hasPrefix("mc.spaces") { return }
        let role = AX.string(el, kAXRoleAttribute)
        if role == kAXButtonRole as String, let frame = AX.frame(el), frame.width >= 8, frame.height >= 8 {
            let title = AX.string(el, kAXTitleAttribute) ?? AX.string(el, kAXDescriptionAttribute) ?? ""
            out.append(Thumbnail(title: title, frame: frame, identifier: identifier,
                                 roleDescription: AX.string(el, kAXRoleDescriptionAttribute)))
            return
        }
        for c in AX.children(el) { collect(c, depth: depth + 1, into: &out) }
    }
}
