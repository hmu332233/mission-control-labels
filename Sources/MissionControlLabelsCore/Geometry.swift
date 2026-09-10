import Foundation
import CoreGraphics

/// AX/Core Graphics(좌상단 원점) ↔ AppKit(좌하단 원점) 좌표 변환을 한곳에 모은다.
/// 모든 값은 pt 단위이며, 주 디스플레이 기준 전역 좌표를 사용한다.
public struct DisplayGeometry: Equatable, Sendable {
    /// 주 디스플레이(원점이 (0,0)인 화면)의 높이. AppKit y 뒤집기의 기준.
    public var primaryHeight: CGFloat
    /// 각 화면의 AppKit 좌표 frame(`NSScreen.frame`). 왼쪽·위쪽 모니터는 음수 좌표를 가질 수 있다.
    public var screenFrames: [CGRect]

    public init(primaryHeight: CGFloat, screenFrames: [CGRect]) {
        self.primaryHeight = primaryHeight
        self.screenFrames = screenFrames
    }

    /// 좌상단 원점 사각형 → AppKit 전역 좌표.
    public func appKitRect(fromTopLeft r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    /// AppKit 전역 좌표 → 좌상단 원점 사각형.
    public func topLeftRect(fromAppKit r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    /// 전역 AppKit 사각형을 특정 화면 frame 기준 로컬 좌표로 바꾼다.
    public func localRect(_ r: CGRect, inScreen screenFrame: CGRect) -> CGRect {
        r.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
    }

    /// 사각형이 가장 많이 겹치는 화면 인덱스. 겹치는 화면이 없으면 nil.
    public func screenIndex(forAppKitRect r: CGRect) -> Int? {
        var best: (index: Int, area: CGFloat)?
        for (i, f) in screenFrames.enumerated() {
            let inter = f.intersection(r)
            guard !inter.isNull, inter.width > 0, inter.height > 0 else { continue }
            let area = inter.width * inter.height
            if best == nil || area > best!.area { best = (i, area) }
        }
        return best?.index
    }
}
