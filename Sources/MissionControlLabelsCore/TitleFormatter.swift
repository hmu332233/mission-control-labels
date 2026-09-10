import Foundation

/// 앱별 창 제목 형식을 표시용 2줄로 정리. 원문에 없는 정보는 추측 보충 금지
public enum TitleFormatter {
    /// VS Code 계열: 기본 제목 형식 `파일 — 워크스페이스 — 앱 이름`. 워크스페이스를 1줄로 승격
    public static let vsCodeFamily: Set<String> = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.visualstudio.code.oss",
        "com.vscodium",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.exafunction.windsurf",
    ]

    static let separators = [" \u{2014} ", " - "] // em dash, hyphen

    public static func lines(title: String, appName: String, bundleID: String?, order: LabelOrder = .default) -> (primary: String?, secondary: String?) {
        if let bundleID, vsCodeFamily.contains(bundleID), let v = vsCode(title: title, appName: appName) {
            switch order {
            case .titleFirst: return (v.workspace, "\(v.file) · \(appName)")
            case .appFirst: return (appName, "\(v.workspace) · \(v.file)")
            }
        }
        switch order {
        case .titleFirst: return (title, appName)
        case .appFirst: return (appName, title)
        }
    }

    /// 반환: (워크스페이스, 파일). 구분자 부재로 워크스페이스 식별 불가 시 nil
    static func vsCode(title: String, appName: String) -> (workspace: String, file: String)? {
        var parts: [String] = []
        for sep in separators where title.contains(sep) {
            parts = title.components(separatedBy: sep).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            break
        }
        if let last = parts.last, last == appName || last == "Visual Studio Code" { parts.removeLast() }
        guard parts.count >= 2 else { return nil }
        // 수정됨 표시(●)는 파일 쪽에 유지
        let workspace = parts[parts.count - 1]
        let file = parts[0..<(parts.count - 1)].joined(separator: " · ")
        return (workspace, file)
    }
}
