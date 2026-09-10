import Foundation
import CoreGraphics

/// 썸네일 좌표와 CG 창 좌표 대응. 모호 시 대응 거부
public struct GeometryMatcher: Sendable {
    public struct Config: Sendable {
        /// 중심점 거리 허용 오차(pt)
        public var centerTolerance: CGFloat
        /// 폭·높이 각각의 허용 오차(pt)
        public var sizeTolerance: CGFloat
        public init(centerTolerance: CGFloat = 4, sizeTolerance: CGFloat = 4) {
            self.centerTolerance = centerTolerance
            self.sizeTolerance = sizeTolerance
        }
    }

    public enum Result: Equatable, Sendable {
        case unique(WindowRecord)
        case ambiguous([WindowRecord])
        case none
    }

    public var config: Config

    public init(config: Config = Config()) { self.config = config }

    public func candidates(for thumb: CGRect, in windows: [WindowRecord]) -> [WindowRecord] {
        windows.filter { w in
            let f = w.frame
            let dx = abs(f.midX - thumb.midX), dy = abs(f.midY - thumb.midY)
            return hypot(dx, dy) <= config.centerTolerance
                && abs(f.width - thumb.width) <= config.sizeTolerance
                && abs(f.height - thumb.height) <= config.sizeTolerance
        }
    }

    public func match(_ thumb: CGRect, in windows: [WindowRecord]) -> Result {
        let c = candidates(for: thumb, in: windows)
        switch c.count {
        case 0: return .none
        case 1: return .unique(c[0])
        default: return .ambiguous(c)
        }
    }
}

/// 썸네일 제목(생략 가능)과 앱 AX 창 제목 목록에서 원래 제목 유일 탐색
public enum TitleMatcher {
    /// 후보 중 정확히 1개만 일치하면 해당 인덱스 반환. 0개 또는 2개 이상이면 nil
    public static func uniqueIndex(thumbnailTitle raw: String, in candidates: [String]) -> Int? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }

        let exact = candidates.indices.filter { candidates[$0] == t }
        if exact.count == 1 { return exact[0] }
        if exact.count > 1 { return nil }

        // 생략 패턴: "앞부분…", "…뒷부분", "앞…뒤"
        let ellipses: [String] = ["\u{2026}", "..."]
        for e in ellipses where t.contains(e) {
            let parts = t.components(separatedBy: e)
            guard parts.count == 2 else { continue }
            let head = parts[0], tail = parts[1]
            guard !(head.isEmpty && tail.isEmpty) else { continue }
            let hits = candidates.indices.filter { i in
                let c = candidates[i]
                return c.count >= head.count + tail.count && c.hasPrefix(head) && c.hasSuffix(tail)
            }
            if hits.count == 1 { return hits[0] }
            return nil
        }
        return nil
    }
}
