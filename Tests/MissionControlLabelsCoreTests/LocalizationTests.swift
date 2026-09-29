import XCTest
@testable import MissionControlLabelsCore

/// `Resources/<lang>.lproj/Localizable.strings` 표가 코드와 어긋나지 않았는지 검증한다.
final class LocalizationTests: XCTestCase {
    /// 코드 기본값과 표가 맞아야 하는 키의 개수
    static let expectedKeyCount = 26

    /// 이 파일에서 패키지 루트까지 (Tests/<타깃>/파일 → Tests → 루트)
    private static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// `"key" = "value";` 형식 줄만 읽는다. `/* */` 주석과 빈 줄은 키가 아니다.
    private func table(_ language: String) throws -> [String: String] {
        let url = Self.packageRoot.appendingPathComponent("Resources/\(language).lproj/Localizable.strings")
        let text = try String(contentsOf: url, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"^"([^"]+)"\s*=\s*"(.*)";\s*$"#)
        var result: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let range = NSRange(location: 0, length: (line as NSString).length)
            guard let match = regex.firstMatch(in: line, range: range) else { continue }
            let key = String(line[Range(match.range(at: 1), in: line)!])
            let value = String(line[Range(match.range(at: 2), in: line)!])
            result[key] = value
        }
        return result
    }

    func testTablesShareTheSameKeys() throws {
        let en = try table("en")
        let ko = try table("ko")
        XCTAssertEqual(en.count, Self.expectedKeyCount)
        XCTAssertEqual(Set(en.keys), Set(ko.keys))
    }

    func testNoValueIsEmpty() throws {
        for language in ["en", "ko"] {
            for (key, value) in try table(language) {
                XCTAssertFalse(value.isEmpty, "\(language): \(key) 값이 비어 있음")
            }
        }
    }

    /// 표를 고쳤는데 코드를 안 고친 경우(그 반대)를 잡는다.
    func testEnglishTableMatchesCodeDefaults() throws {
        let en = try table("en")
        XCTAssertEqual(en["menu.quit"], "Quit")
        XCTAssertEqual(en["anchor.center"], LabelAnchor.center.displayName)
        XCTAssertEqual(en["order.appFirst"], LabelOrder.appFirst.displayName)
    }

    func testFormatPlaceholdersMatchAcrossLanguages() throws {
        let en = try table("en")
        let ko = try table("ko")
        for key in ["menu.state", "state.diagnostics.saved"] {
            XCTAssertTrue(en[key]?.contains("%@") ?? false, "en: \(key)에 %@가 없음")
            XCTAssertTrue(ko[key]?.contains("%@") ?? false, "ko: \(key)에 %@가 없음")
        }
    }
}
