import XCTest
@testable import MissionControlLabelsCore

final class GeometryTests: XCTestCase {
    // 주 화면 1000pt 높이, 왼쪽에 외장 화면(음수 x), 위에 외장 화면(양수 y in AppKit)
    let geo = DisplayGeometry(primaryHeight: 1000,
                              screenFrames: [CGRect(x: 0, y: 0, width: 1600, height: 1000),
                                             CGRect(x: -1920, y: -80, width: 1920, height: 1080),
                                             CGRect(x: 200, y: 1000, width: 1440, height: 900)])

    func testTopLeftToAppKitRoundTrip() {
        let tl = CGRect(x: 100, y: 200, width: 300, height: 150)
        let ak = geo.appKitRect(fromTopLeft: tl)
        XCTAssertEqual(ak, CGRect(x: 100, y: 650, width: 300, height: 150))
        XCTAssertEqual(geo.topLeftRect(fromAppKit: ak), tl)
    }

    func testNegativeCoordinatesOnLeftScreen() {
        // CG 좌표: 왼쪽 화면은 x가 음수. 위쪽 화면은 CG y가 음수.
        let tl = CGRect(x: -1500, y: 300, width: 400, height: 200)
        let ak = geo.appKitRect(fromTopLeft: tl)
        XCTAssertEqual(ak.origin.y, 500)
        XCTAssertEqual(geo.screenIndex(forAppKitRect: ak), 1)
        let local = geo.localRect(ak, inScreen: geo.screenFrames[1])
        XCTAssertEqual(local.origin, CGPoint(x: 420, y: 580))
    }

    func testAboveScreenNegativeCGY() {
        let tl = CGRect(x: 300, y: -500, width: 200, height: 100) // CG y 음수 = 위쪽 모니터
        let ak = geo.appKitRect(fromTopLeft: tl)
        XCTAssertEqual(ak.origin.y, 1400)
        XCTAssertEqual(geo.screenIndex(forAppKitRect: ak), 2)
    }

    func testScreenIndexPicksLargestIntersection() {
        let straddle = CGRect(x: -100, y: 100, width: 300, height: 100) // 왼쪽 100, 주 화면 200
        XCTAssertEqual(geo.screenIndex(forAppKitRect: straddle), 0)
        XCTAssertNil(geo.screenIndex(forAppKitRect: CGRect(x: 5000, y: 5000, width: 10, height: 10)))
    }
}

final class MatcherTests: XCTestCase {
    func w(_ id: UInt32, _ pid: Int32, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> WindowRecord {
        WindowRecord(windowID: id, ownerPID: pid, frame: CGRect(x: x, y: y, width: w, height: h), layer: 0)
    }

    func testUniqueMatchWithinTolerance() {
        let m = GeometryMatcher()
        let wins = [w(1, 10, 100, 100, 400, 300), w(2, 11, 600, 100, 400, 300)]
        XCTAssertEqual(m.match(CGRect(x: 101, y: 99, width: 401, height: 299), in: wins), .unique(wins[0]))
    }

    func testAmbiguousIsRejected() {
        let m = GeometryMatcher()
        let wins = [w(1, 10, 100, 100, 400, 300), w(2, 11, 101, 101, 400, 300)]
        if case .ambiguous(let c) = m.match(CGRect(x: 100, y: 100, width: 400, height: 300), in: wins) {
            XCTAssertEqual(c.count, 2)
        } else { XCTFail("expected ambiguous") }
    }

    func testNoMatchWhenSizeDiffers() {
        let m = GeometryMatcher()
        let wins = [w(1, 10, 100, 100, 400, 300)]
        XCTAssertEqual(m.match(CGRect(x: 100, y: 100, width: 420, height: 300), in: wins), .none)
    }
}

final class TitleMatcherTests: XCTestCase {
    func testExactUnique() {
        XCTAssertEqual(TitleMatcher.uniqueIndex(thumbnailTitle: "b", in: ["a", "b", "c"]), 1)
    }
    func testExactDuplicateRejected() {
        XCTAssertNil(TitleMatcher.uniqueIndex(thumbnailTitle: "b", in: ["b", "b"]))
    }
    func testEllipsisTail() {
        XCTAssertEqual(TitleMatcher.uniqueIndex(thumbnailTitle: "프로젝트 문서…", in: ["프로젝트 문서 — Google Docs", "메모"]), 0)
    }
    func testEllipsisMiddleAmbiguous() {
        XCTAssertNil(TitleMatcher.uniqueIndex(thumbnailTitle: "a…z", in: ["abcz", "axyz"]))
    }
    func testEmptyRejected() {
        XCTAssertNil(TitleMatcher.uniqueIndex(thumbnailTitle: "  ", in: ["x"]))
    }
}

final class LayoutAndSessionTests: XCTestCase {
    func t(_ title: String, _ x: CGFloat, _ y: CGFloat) -> Thumbnail {
        Thumbnail(title: title, frame: CGRect(x: x, y: y, width: 200, height: 120))
    }

    func testStabilityRequiresSameCountAndPositions() {
        XCTAssertTrue(LayoutStability.isStable([t("a", 0, 0)], [t("a", 0.5, 0.5)]))
        XCTAssertFalse(LayoutStability.isStable([t("a", 0, 0)], [t("a", 3, 0)]))
        XCTAssertFalse(LayoutStability.isStable([t("a", 0, 0)], [t("a", 0, 0), t("b", 300, 0)]))
        XCTAssertFalse(LayoutStability.isStable([], []))
    }

    func lines(_ app: String?, _ title: String?) -> [String?] {
        let l = ResolvedLabel(frame: .zero, appName: app, title: title, confidence: .geometry).displayLines
        return [l.primary, l.secondary]
    }

    func testDisplayLinesRulesTitleFirst() {
        XCTAssertEqual(lines("Safari", "Safari"), ["Safari", nil])
        XCTAssertEqual(lines("Safari", "  "), ["Safari", nil])
        XCTAssertEqual(lines(nil, "Doc"), ["Doc", nil])
        XCTAssertEqual(lines("A", "B"), ["B", "A"])
    }

    func testVSCodeWorkspaceFirst() {
        let l = ResolvedLabel(frame: .zero, appName: "Code", bundleID: "com.microsoft.VSCode",
                              title: "LabelView.swift — mission-control-labels — Visual Studio Code", confidence: .geometry).displayLines
        XCTAssertEqual(l.primary, "mission-control-labels")
        XCTAssertEqual(l.secondary, "LabelView.swift · Code")
        // 앱 이름 없이 두 조각만 있는 형식
        let m = ResolvedLabel(frame: .zero, appName: "Code", bundleID: "com.microsoft.VSCode",
                              title: "● main.swift — proj", confidence: .geometry).displayLines
        XCTAssertEqual(m.primary, "proj")
        XCTAssertEqual(m.secondary, "● main.swift · Code")
        // 구분자 없음 → 일반 규칙
        let n = ResolvedLabel(frame: .zero, appName: "Code", bundleID: "com.microsoft.VSCode",
                              title: "Welcome", confidence: .geometry).displayLines
        XCTAssertEqual(n.primary, "Welcome")
        XCTAssertEqual(n.secondary, "Code")
    }

    func testStaleSessionResultIsDiscarded() {
        let s = SessionCounter()
        let old = s.advance()
        XCTAssertTrue(s.isCurrent(old))
        s.advance()
        XCTAssertFalse(s.isCurrent(old))
    }

    func testTitleLineLimitPrefersAppName() {
        XCTAssertEqual(LabelLayoutPolicy.titleLineLimit(forThumbnailHeight: 40), 0)
        XCTAssertEqual(LabelLayoutPolicy.titleLineLimit(forThumbnailHeight: 90), 1)
        XCTAssertEqual(LabelLayoutPolicy.titleLineLimit(forThumbnailHeight: 300), 2)
    }
}


final class LabelAnchorTests: XCTestCase {
    let thumb = CGRect(x: 100, y: 200, width: 400, height: 300)
    let size = CGSize(width: 120, height: 50)

    func testOrigins() {
        XCTAssertEqual(LabelAnchor.center.origin(labelSize: size, in: thumb, inset: 8), CGPoint(x: 240, y: 325))
        XCTAssertEqual(LabelAnchor.topLeft.origin(labelSize: size, in: thumb, inset: 8), CGPoint(x: 108, y: 442))
        XCTAssertEqual(LabelAnchor.topRight.origin(labelSize: size, in: thumb, inset: 8), CGPoint(x: 372, y: 442))
        XCTAssertEqual(LabelAnchor.bottomLeft.origin(labelSize: size, in: thumb, inset: 8), CGPoint(x: 108, y: 208))
        XCTAssertEqual(LabelAnchor.bottomRight.origin(labelSize: size, in: thumb, inset: 8), CGPoint(x: 372, y: 208))
    }

    func testLabelStaysInsideThumbnail() {
        for a in LabelAnchor.allCases {
            let o = a.origin(labelSize: size, in: thumb, inset: 8)
            XCTAssertTrue(thumb.contains(CGRect(origin: o, size: size)), "\(a)")
        }
    }
}
