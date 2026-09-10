import Foundation
import CoreGraphics

/// 연속 관측 사이의 배치 안정 여부 판정.
public enum LayoutStability {
    /// 두 관측의 썸네일 수가 같고, 각 위치·크기가 순서대로 tolerance 안에 있으면 안정.
    public static func isStable(_ a: [Thumbnail], _ b: [Thumbnail], tolerance: CGFloat = 1.0) -> Bool {
        guard a.count == b.count, !a.isEmpty else { return false }
        for (x, y) in zip(a, b) {
            if x.title != y.title { return false }
            if abs(x.frame.minX - y.frame.minX) > tolerance { return false }
            if abs(x.frame.minY - y.frame.minY) > tolerance { return false }
            if abs(x.frame.width - y.frame.width) > tolerance { return false }
            if abs(x.frame.height - y.frame.height) > tolerance { return false }
        }
        return true
    }
}

/// 라벨 텍스트 줄 수 결정. 작은 썸네일에서는 앱 이름을 우선한다.
public enum LabelLayoutPolicy {
    public static func titleLineLimit(forThumbnailHeight h: CGFloat) -> Int {
        if h < 70 { return 0 }
        if h < 130 { return 1 }
        return 2
    }
}
