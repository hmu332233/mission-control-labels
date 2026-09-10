import Foundation
import CoreGraphics

/// Mission Control 썸네일 1개. `frame`은 Core Graphics 전역 좌표(주 디스플레이 좌상단 원점, pt)
public struct Thumbnail: Equatable, Sendable {
    public var title: String
    public var frame: CGRect
    public var identifier: String?
    public var roleDescription: String?

    public init(title: String, frame: CGRect, identifier: String? = nil, roleDescription: String? = nil) {
        self.title = title
        self.frame = frame
        self.identifier = identifier
        self.roleDescription = roleDescription
    }
}

/// `CGWindowListCopyWindowInfo`에서 읽은 창 1개. `frame`은 Thumbnail과 동일 좌표계
public struct WindowRecord: Equatable, Sendable {
    public var windowID: UInt32
    public var ownerPID: Int32
    public var frame: CGRect
    public var layer: Int
    public var ownerName: String?

    public init(windowID: UInt32, ownerPID: Int32, frame: CGRect, layer: Int, ownerName: String? = nil) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.frame = frame
        self.layer = layer
        self.ownerName = ownerName
    }
}

public struct ResolvedLabel: Equatable, Sendable {
    public enum Confidence: String, Sendable {
        /// 썸네일 좌표가 CG 창 1개와 유일하게 대응됨
        case geometry
        /// 좌표 대응 실패, 단 제목이 화면 전체에서 유일하게 창 1개와 일치함
        case titleUnique
        /// 앱 미확정. 썸네일 제목만 표시
        case thumbnailOnly
    }

    public var frame: CGRect
    public var appName: String?
    public var bundleID: String?
    public var title: String?
    public var confidence: Confidence

    public init(frame: CGRect, appName: String?, bundleID: String? = nil, title: String?, confidence: Confidence) {
        self.frame = frame
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
        self.confidence = confidence
    }

    /// 표시 규칙(기본 제목 우선): 1줄 제목, 2줄 앱 이름. `order`가 `.appFirst`면 순서 교체
    /// 제목이 비었거나 앱 이름과 같으면 앱 이름만 표시. 앱별 제목 형식은 TitleFormatter가 정리
    public var displayLines: (primary: String?, secondary: String?) { displayLines(order: .default) }

    public func displayLines(order: LabelOrder) -> (primary: String?, secondary: String?) {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = (trimmedTitle?.isEmpty == false) ? trimmedTitle : nil
        guard let app = appName, !app.isEmpty else {
            return (t, nil)
        }
        guard let t, t != app else { return (app, nil) }
        return TitleFormatter.lines(title: t, appName: app, bundleID: bundleID, order: order)
    }
}

/// 진단·로그용 집계. 창 제목 등 개인 정보 미포함
public struct ResolveStats: Equatable, Sendable {
    public var thumbnailCount = 0
    public var candidateWindowCount = 0
    public var uniqueMatches = 0
    public var ambiguousMatches = 0
    public var unmatched = 0
    public var titleUniqueFallbacks = 0
    public var originalTitleResolved = 0
    public var elapsed: TimeInterval = 0

    public init() {}
}
