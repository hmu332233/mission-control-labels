import Foundation

public enum LabelOrder: String, CaseIterable, Sendable {
    /// 1줄 창 제목(워크스페이스), 2줄 앱 이름
    case titleFirst
    /// 1줄 앱 이름, 2줄 창 제목(워크스페이스)
    case appFirst

    public static let `default`: LabelOrder = .titleFirst

    public var displayName: String {
        switch self {
        case .titleFirst: return "제목 / 앱 이름"
        case .appFirst: return "앱 이름 / 제목"
        }
    }
}
