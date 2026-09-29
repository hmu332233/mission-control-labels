import Foundation
import CoreGraphics

public enum LabelAnchor: String, CaseIterable, Sendable {
    case center, topLeft, topRight, bottomLeft, bottomRight

    public static let `default`: LabelAnchor = .center

    public var displayName: String {
        switch self {
        case .center: return "Center"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }

    /// Localizable.strings에서 메뉴 제목을 찾는 키
    public var localizationKey: String { "anchor.\(rawValue)" }

    public enum TextAlignment: Sendable { case left, center, right }

    public var textAlignment: TextAlignment {
        switch self {
        case .center: return .center
        case .topLeft, .bottomLeft: return .left
        case .topRight, .bottomRight: return .right
        }
    }

    /// AppKit 좌표(y 위로 증가)의 썸네일 사각형 안에 크기 `size`의 라벨을 놓을 원점
    public func origin(labelSize size: CGSize, in thumb: CGRect, inset: CGFloat) -> CGPoint {
        let x: CGFloat, y: CGFloat
        switch self {
        case .center:
            x = thumb.midX - size.width / 2
            y = thumb.midY - size.height / 2
        case .topLeft:
            x = thumb.minX + inset
            y = thumb.maxY - inset - size.height
        case .topRight:
            x = thumb.maxX - inset - size.width
            y = thumb.maxY - inset - size.height
        case .bottomLeft:
            x = thumb.minX + inset
            y = thumb.minY + inset
        case .bottomRight:
            x = thumb.maxX - inset - size.width
            y = thumb.minY + inset
        }
        return CGPoint(x: round(x), y: round(y))
    }
}
