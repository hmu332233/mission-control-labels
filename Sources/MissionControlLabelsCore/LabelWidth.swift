import Foundation
import CoreGraphics

/// 라벨 폭의 상한. 썸네일 폭만 쓰면 창이 여러 개인 배치에서 긴 제목이 말줄임으로 잘린다.
/// 썸네일 주변에는 아무것도 없는 빈 공간이 많으므로 라벨은 썸네일 밖으로 넓어질 수 있되,
/// 다른 썸네일 위와 화면 밖으로는 나가지 않는다. 라벨은 이미 내용 폭까지만 넓어지므로
/// 상한을 키워도 짧은 제목의 카드는 그대로 좁다
public enum LabelWidthPolicy {
    /// 가로 공간을 다투는 상대인지. 라벨은 자기 썸네일 세로 범위 안에만 들어 있으므로
    /// 세로로 겹치지 않으면 그 썸네일과 겹칠 일이 없다
    static func sharesRow(_ a: CGRect, _ b: CGRect) -> Bool {
        min(a.maxY, b.maxY) - max(a.minY, b.minY) > 0
    }

    /// 라벨이 침범할 수 있는 가로 구간. 두 라벨이 같은 빈 공간을 통째로 쓰려고 하면 서로
    /// 겹치므로, 세로로 같은 줄의 이웃 썸네일까지의 빈 공간은 정중앙에서 반씩 나눈다
    public static func interval(for thumb: CGRect, others: [CGRect], screen: CGSize, inset: CGFloat) -> (minX: CGFloat, maxX: CGFloat) {
        var minX = inset
        var maxX = screen.width - inset
        for o in others where sharesRow(o, thumb) {
            if o.maxX <= thumb.minX { minX = Swift.max(minX, (thumb.minX + o.maxX) / 2) }
            if o.minX >= thumb.maxX { maxX = Swift.min(maxX, (thumb.maxX + o.minX) / 2) }
        }
        return (minX, maxX)
    }

    /// 앵커별 폭 상한. 카드는 앵커 지점에서 뻗어나가므로 중앙 정렬은 좌우 여유 중 작은 쪽의
    /// 두 배, 왼쪽 정렬은 오른쪽 여유, 오른쪽 정렬은 왼쪽 여유만큼 넓어진다
    public static func maxWidth(thumb: CGRect, others: [CGRect], screen: CGSize, inset: CGFloat,
                               anchor: LabelAnchor) -> CGFloat {
        let room = interval(for: thumb, others: others, screen: screen, inset: inset)
        switch anchor.textAlignment {
        case .center: return 2 * max(0, min(thumb.midX - room.minX, room.maxX - thumb.midX))
        case .left: return max(0, room.maxX - (thumb.minX + inset))
        case .right: return max(0, (thumb.maxX - inset) - room.minX)
        }
    }

    /// 화면 안의 모든 썸네일에 대한 폭 상한. 이웃을 함께 봐야 정하므로 한 화면 단위로 계산한다
    public static func maxWidths(_ thumbs: [CGRect], screen: CGSize, inset: CGFloat,
                                anchor: LabelAnchor) -> [CGFloat] {
        thumbs.indices.map { i in
            maxWidth(thumb: thumbs[i], others: thumbs.enumerated().filter { $0.offset != i }.map(\.element),
                     screen: screen, inset: inset, anchor: anchor)
        }
    }
}
