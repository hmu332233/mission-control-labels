import AppKit
import ApplicationServices
import MissionControlLabelsCore

/// Dock 프로세스의 Accessibility 트리에서 Mission Control 그룹과 창 썸네일을 읽는다.
final class MissionControlReader {
    static let dockBundleID = "com.apple.dock"
    /// Dock AX 응답 제한 시간(초). 기술 검증 후 조정.
    static let messagingTimeout: Float = 0.3

    private var dockPID: pid_t?
    private var dockElement: AXUIElement?

    /// Dock PID가 바뀌면 기존 핸들을 버리고 다시 만든다.
    func dockApplication() -> AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: Self.dockBundleID).first else {
            dockPID = nil; dockElement = nil
            return nil
        }
        if dockPID != app.processIdentifier || dockElement == nil {
            let el = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(el, Self.messagingTimeout)
            dockPID = app.processIdentifier
            dockElement = el
        }
        return dockElement
    }

    var currentDockPID: pid_t? { dockPID }

    /// Mission Control이 열려 있을 때만 존재하는 그룹. 식별자 "mc"를 우선, 제목 비교는 보조.
    func missionControlGroup() -> AXUIElement? {
        guard let dock = dockApplication() else { return nil }
        let children = AX.children(dock)
        if let byID = children.first(where: { AX.string($0, kAXIdentifierAttribute) == "mc" }) { return byID }
        return children.first(where: {
            AX.string($0, kAXRoleAttribute) == kAXGroupRole as String
                && AX.string($0, kAXTitleAttribute) == "Mission Control"
        })
    }

    /// 그룹 아래의 창 썸네일. 상단 Spaces 막대(mc.spaces*) 하위 트리는 제외한다.
    func thumbnails(in group: AXUIElement) -> [Thumbnail] {
        var out: [Thumbnail] = []
        collect(group, depth: 0, into: &out)
        // 왼쪽 위부터 읽는 순서로 정렬해 연속 관측 비교를 안정시킨다.
        out.sort { a, b in
            if abs(a.frame.minY - b.frame.minY) > 2 { return a.frame.minY < b.frame.minY }
            return a.frame.minX < b.frame.minX
        }
        return out
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

    /// 진단용 트리 덤프. 개발 중 명시적으로 켠 경우에만 호출된다.
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
}
