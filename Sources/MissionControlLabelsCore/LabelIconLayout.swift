import Foundation

/// Расположение иконки приложения в 라벨
public enum LabelIconLayout: String, CaseIterable, Sendable {
    /// 앱 이름 줄 안쪽, 텍스트와 나란히 (기본)
    case inLine
    /// 라벨 카드 왼쪽의 별도 칸. 세로 중앙, 텍스트는 오른쪽 블록으로 좌측 정렬
    case leading

    public static let `default`: LabelIconLayout = .inLine

    public var displayName: String {
        switch self {
        case .inLine: return "In Line"
        case .leading: return "Left of Text"
        }
    }
}
