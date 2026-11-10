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
        // CG 좌표: 왼쪽 화면은 x 음수, 위쪽 화면은 CG y 음수
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

    func testAppFirstOrderSwapsLines() {
        let plain = ResolvedLabel(frame: .zero, appName: "A", title: "B", confidence: .geometry).displayLines(order: .appFirst)
        XCTAssertEqual(plain.primary, "A")
        XCTAssertEqual(plain.secondary, "B")
        // 제목이 없거나 앱 이름과 같으면 순서와 무관하게 한 줄
        let same = ResolvedLabel(frame: .zero, appName: "Safari", title: "Safari", confidence: .geometry).displayLines(order: .appFirst)
        XCTAssertEqual(same.primary, "Safari")
        XCTAssertNil(same.secondary)
        // VS Code: 1줄 앱 이름, 2줄 "워크스페이스 · 파일"
        let code = ResolvedLabel(frame: .zero, appName: "Code", bundleID: "com.microsoft.VSCode",
                                 title: "LabelView.swift — mission-control-labels — Visual Studio Code", confidence: .geometry).displayLines(order: .appFirst)
        XCTAssertEqual(code.primary, "Code")
        XCTAssertEqual(code.secondary, "mission-control-labels · LabelView.swift")
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

/// 라벨은 썸네일 밖의 빈 공간까지 쓸 수 있다. 다만 다른 썸네일 위와 화면 밖, 다른 라벨 자리로는 나가지 않는다
final class LabelWidthPolicyTests: XCTestCase {
    let screen = CGSize(width: 1600, height: 1000)
    let inset: CGFloat = 8
    let thumb = CGRect(x: 100, y: 100, width: 300, height: 200)

    func limit(_ anchor: LabelAnchor, others: [CGRect] = []) -> CGFloat {
        LabelWidthPolicy.maxWidth(thumb: thumb, others: others, screen: screen, inset: inset, anchor: anchor)
    }

    func testUsesFreeSpaceUpToTheScreenEdge() {
        // 썸네일 폭 상한(284)으로는 긴 제목이 잘렸다. 주변이 비었으면 중앙 라벨은 왼쪽 여유(242)까지 왕복
        XCTAssertEqual(limit(.center), 484)
        // 왼쪽 배치는 시작점(108)에서 화면 오른쪽 여유까지
        XCTAssertEqual(limit(.bottomLeft), 1592 - 108)
    }

    func testNeighbourInSameRowSplitsTheGap() {
        let a = thumb
        let b = CGRect(x: 500, y: 110, width: 300, height: 200) // 세로로 조금 어긋나도 같은 줄로 본다
        // 빈 공간(400…500)의 정중앙 450을 경계로 삼는다
        XCTAssertEqual(LabelWidthPolicy.maxWidths([a, b], screen: screen, inset: inset, anchor: .center), [400, 400])
    }

    func testNeighbourInAnotherRowDoesNotLimit() {
        XCTAssertEqual(limit(.center, others: [CGRect(x: 100, y: 500, width: 300, height: 200)]), 484)
    }

    func testCornerAnchorsGrowAwayFromTheNeighbour() {
        let b = CGRect(x: 500, y: 100, width: 300, height: 200)
        XCTAssertEqual(limit(.topLeft, others: [b]), 450 - 108)
        // 오른쪽 배치는 왼쪽(화면 여백) 여유만 쓴다
        XCTAssertEqual(limit(.topRight, others: [b]), 400 - inset * 2)
    }

    func testThumbnailAtScreenEdgeKeepsTheOldLimit() {
        let edge = CGRect(x: 0, y: 100, width: 300, height: 200)
        XCTAssertEqual(LabelWidthPolicy.maxWidth(thumb: edge, others: [], screen: screen, inset: inset, anchor: .center),
                       300 - inset * 2)
    }

    /// 두 라벨이 같은 빈 공간을 통째로 쓰려고 해도 경계를 반씩 나눠 겹치지 않는다
    func testMaximalLabelsDoNotOverlapEachOther() {
        let row = [thumb, CGRect(x: 430, y: 100, width: 300, height: 200), CGRect(x: 760, y: 100, width: 300, height: 200)]
        let widths = LabelWidthPolicy.maxWidths(row, screen: screen, inset: inset, anchor: .center)
        XCTAssertTrue(widths.contains { $0 > 300 }, "빈 공간을 썼는지 확인: \(widths)")
        let height: CGFloat = 50
        let rects = zip(row, widths).map { t, w -> CGRect in
            CGRect(origin: LabelAnchor.center.origin(labelSize: CGSize(width: w, height: height), in: t, inset: inset),
                   size: CGSize(width: w, height: height))
        }
        for (i, r) in rects.enumerated() {
            for other in rects.dropFirst(i + 1) {
                let inter = r.intersection(other)
                XCTAssertTrue(inter.isNull || inter.width <= 0, "라벨이 겹침: \(r) \(other)")
            }
        }
    }
}

/// 라벨 외관 옵션(아이콘 위치·배율)이 메뉴에 저장한 문자열로 되돌아오는지
final class LabelAppearanceOptionTests: XCTestCase {
    func testScaleFactorsMatchDisplayedPercentages() {
        XCTAssertEqual(LabelScale.hundred.factor, 1)
        XCTAssertEqual(LabelScale.oneTwentyFive.factor, 1.25)
        XCTAssertEqual(LabelScale.oneFifty.factor, 1.5)
        XCTAssertEqual(LabelScale.default, .hundred)
        // 메뉴는 배율을 "125%" 같은 문자열로 저장하므로 그대로 되돌아와야 한다
        for scale in LabelScale.allCases { XCTAssertEqual(LabelScale(rawValue: scale.rawValue), scale) }
        XCTAssertNil(LabelScale(rawValue: "200%"))
    }

    func testIconLayoutRoundTripAndDefault() {
        XCTAssertEqual(LabelIconLayout.default, .inLine)
        for layout in LabelIconLayout.allCases { XCTAssertEqual(LabelIconLayout(rawValue: layout.rawValue), layout) }
        XCTAssertNil(LabelIconLayout(rawValue: "top"))
    }
}
