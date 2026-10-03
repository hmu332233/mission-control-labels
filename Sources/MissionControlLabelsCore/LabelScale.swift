import Foundation

/// 라벨 전체 배율. 텍스트·여백·그림자·아이콘 크기가 함께 커진다
public enum LabelScale: String, CaseIterable, Sendable {
    case hundred = "100%"
    case oneTwentyFive = "125%"
    case oneFifty = "150%"

    public static let `default`: LabelScale = .hundred

    public var factor: CGFloat {
        switch self {
        case .hundred: return 1
        case .oneTwentyFive: return 1.25
        case .oneFifty: return 1.5
        }
    }

    public var displayName: String { rawValue }
}
