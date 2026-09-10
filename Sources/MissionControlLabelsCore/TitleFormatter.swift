import Foundation

/// 앱별 창 제목 형식을 표시용 두 줄로 정리한다. 원문에 없는 정보를 추측해 보충하지 않는다.
public enum TitleFormatter {
    /// VS Code 계열: 기본 제목 형식 `파일 — 워크스페이스 — 앱 이름`. 워크스페이스를 1줄로 올린다.
    public static let vsCodeFamily: Set<String> = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.visualstudio.code.oss",
        "com.vscodium",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.exafunction.windsurf",
    ]

    static let separators = [" \u{2014} ", " - "] // em dash, hyphen

    public static func lines(title: String, appName: String, bundleID: String?) -> (primary: String?, secondary: String?) {
        if let bundleID, vsCodeFamily.contains(bundleID), let v = vsCode(title: title, appName: appName) {
            return v
        }
        return (title, appName)
    }

    /// 반환: (워크스페이스, "파일 · 앱 이름"). 구분자가 없어 워크스페이스를 알 수 없으면 nil.
    static func vsCode(title: String, appName: String) -> (primary: String?, secondary: String?)? {
        var parts: [String] = []
        for sep in separators where title.contains(sep) {
            parts = title.components(separatedBy: sep).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            break
        }
        // 뒤에 붙는 앱 이름 제거
        if let last = parts.last, last == appName || last == "Visual Studio Code" { parts.removeLast() }
        guard parts.count >= 2 else { return nil }
        // 수정됨 표시(●)는 파일 쪽에 남긴다.
        let workspace = parts[parts.count - 1]
        let file = parts[0..<(parts.count - 1)].joined(separator: " · ")
        return (workspace, "\(file) · \(appName)")
    }
}
