import Foundation

/// 로케일화된 메뉴 문자열. `<lang>.lproj/Localizable.strings` 표를 번들에 복사하는 것은 scripts/build-app.sh 역할.
/// 번들이 없는 경우(`swift run`) 표가 없으므로 인자 `defaultText`의 영어 기본값을 그대로 반환한다.
enum L10n {
    static func string(_ key: String, _ defaultText: String) -> String {
        NSLocalizedString(key, bundle: .main, value: defaultText, comment: "")
    }

    static func string(_ key: String, _ defaultText: String, _ arguments: CVarArg...) -> String {
        String(format: string(key, defaultText), arguments: arguments)
    }
}
