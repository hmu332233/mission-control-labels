import Foundation

public enum LabelOrder: String, CaseIterable, Sendable {
    /// 1줄 창 제목(워크스페이스), 2줄 앱 이름
    case titleFirst
    /// 1줄 앱 이름, 2줄 창 제목(워크스페이스)
    case appFirst

    public static let `default`: LabelOrder = .titleFirst

    public var displayName: String {
        switch self {
        case .titleFirst: return "Title / App Name"
        case .appFirst: return "App Name / Title"
        }
    }

    /// Localizable.strings에서 메뉴 제목을 찾는 키
    public var localizationKey: String { "order.\(rawValue)" }
}
