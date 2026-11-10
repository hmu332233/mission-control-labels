import Foundation
import CoreGraphics

/// 썸네일 좌표와 CG 창 좌표 대응. 모호 시 대응 거부
public struct GeometryMatcher: Sendable {
    public struct Config: Sendable {
        /// 중심점 거리 허용 오차(pt). macOS 27은 미리보기을 카드 테두리 안쪽에 그려 실창 중심과 수십 pt 어긋난다
        public var centerTolerance: CGFloat
        /// 미리보기이 실창보다 클 수 있는 범위(pt). 크게 어긋나면 다른 창으로 오판정
        public var thumbOversizeTolerance: CGFloat
        /// 실창이 미리보기이보다 클 수 있는 범위(pt). 카드 테두리·그림자 두께
        public var windowOversizeTolerance: CGFloat
        public init(centerTolerance: CGFloat = 24, thumbOversizeTolerance: CGFloat = 6, windowOversizeTolerance: CGFloat = 40) {
            self.centerTolerance = centerTolerance
            self.thumbOversizeTolerance = thumbOversizeTolerance
            self.windowOversizeTolerance = windowOversizeTolerance
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
                && thumb.width - f.width <= config.thumbOversizeTolerance
                && thumb.height - f.height <= config.thumbOversizeTolerance
                && f.width - thumb.width <= config.windowOversizeTolerance
                && f.height - thumb.height <= config.windowOversizeTolerance
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
