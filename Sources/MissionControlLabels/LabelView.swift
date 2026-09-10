import AppKit
import MissionControlLabelsCore

/// 1줄 주 정보(창 제목·워크스페이스, 최대 2줄)와 2줄 보조 정보(앱 이름, 1줄)를 반투명 글래스 카드 위에 중앙 정렬로 그리는 라벨. 아이콘 없음
/// 디자인 근거: design/spec.md 시안 A(카드). 배경은 뒤 화면과 무관한 고정 단색
final class LabelView: NSView {
    static let appFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
    static let titleFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    static let appColor = NSColor.white
    static let titleColor = NSColor.white.withAlphaComponent(0.78)
    /// 카드 배경. 블러·비침 없이 어디서나 동일 색으로 보이도록 거의 불투명한 어두운 회색 사용
    static let cardBackground = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 0.92)
    static let border = NSColor.white.withAlphaComponent(0.18)
    static let paddingH: CGFloat = 16
    static let paddingV: CGFloat = 11
    static let lineGap: CGFloat = 3
    static let cornerRadius: CGFloat = 14
    /// 카드 최대 폭. 큰 썸네일에서도 과도한 확장 방지
    static let maxCardWidth: CGFloat = 400

    private let text: TextLayer

    init(label: ResolvedLabel, maxWidth: CGFloat, titleLineLimit: Int, alignment: LabelAnchor.TextAlignment = .center, order: LabelOrder = .default) {
        let cardMax = min(maxWidth, Self.maxCardWidth)
        text = TextLayer(label: label, textWidth: max(24, cardMax - Self.paddingH * 2), titleLineLimit: titleLineLimit, alignment: alignment, order: order)
        let size = NSSize(width: min(cardMax, text.contentSize.width + Self.paddingH * 2),
                          height: text.contentSize.height + Self.paddingV * 2)
        super.init(frame: NSRect(origin: .zero, size: size))
        wantsLayer = true
        // 시안 A: 패널 그림자 x0 / y4 / blur16 / 검정 16%
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        self.shadow = shadow

        let background = Self.makeBackground(frame: bounds)
        background.autoresizingMask = [.width, .height]
        addSubview(background)

        let borderView = BorderView(frame: bounds)
        borderView.autoresizingMask = [.width, .height]
        addSubview(borderView)

        text.frame = bounds.insetBy(dx: Self.paddingH, dy: Self.paddingV)
        text.autoresizingMask = [.width, .height]
        addSubview(text)
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func makeBackground(frame: NSRect) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true
        v.layer?.backgroundColor = cardBackground.cgColor
        v.layer?.cornerRadius = cornerRadius
        v.layer?.cornerCurve = .continuous
        return v
    }

    private final class BorderView: NSView {
        override func draw(_ dirtyRect: NSRect) {
            // 물리 1px 테두리(Retina 2×에서 0.5pt)
            let scale = window?.backingScaleFactor ?? 2
            let w = 1 / scale
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: w / 2, dy: w / 2),
                                    xRadius: LabelView.cornerRadius, yRadius: LabelView.cornerRadius)
            LabelView.border.setStroke()
            path.lineWidth = w
            path.stroke()
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    /// 텍스트 측정·그리기. 중앙 정렬, 마지막 줄 말줄임
    private final class TextLayer: NSView {
        let primary: String?
        let secondary: String?
        let primaryHeight: CGFloat
        let secondaryHeight: CGFloat
        let contentSize: CGSize
        let alignment: NSTextAlignment

        init(label: ResolvedLabel, textWidth: CGFloat, titleLineLimit: Int, alignment: LabelAnchor.TextAlignment, order: LabelOrder) {
            switch alignment {
            case .left: self.alignment = .left
            case .center: self.alignment = .center
            case .right: self.alignment = .right
            }
            let lines = label.displayLines(order: order)
            primary = lines.primary
            secondary = titleLineLimit > 0 ? lines.secondary : nil
            var pw: CGFloat = 0, ph: CGFloat = 0, sw: CGFloat = 0, sh: CGFloat = 0
            if let p = primary {
                let r = TextLayer.measure(p, width: textWidth, attrs: TextLayer.attrs(LabelView.appFont, LabelView.appColor), maxLines: max(1, titleLineLimit))
                pw = r.width; ph = r.height
            }
            if let s = secondary {
                let r = TextLayer.measure(s, width: textWidth, attrs: TextLayer.attrs(LabelView.titleFont, LabelView.titleColor), maxLines: 1)
                sw = r.width; sh = r.height
            }
            primaryHeight = ph
            secondaryHeight = sh
            let gap: CGFloat = (primary != nil && secondary != nil) ? LabelView.lineGap : 0
            contentSize = CGSize(width: ceil(max(pw, sw)), height: ceil(ph + sh + gap))
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }
        override var isFlipped: Bool { true }

        static func attrs(_ font: NSFont, _ color: NSColor, _ alignment: NSTextAlignment = .center) -> [NSAttributedString.Key: Any] {
            let ps = NSMutableParagraphStyle()
            ps.lineBreakMode = .byWordWrapping
            ps.alignment = alignment
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
            shadow.shadowBlurRadius = 2
            shadow.shadowOffset = NSSize(width: 0, height: -0.5)
            return [.font: font, .foregroundColor: color, .paragraphStyle: ps, .shadow: shadow]
        }

        static func measure(_ s: String, width: CGFloat, attrs: [NSAttributedString.Key: Any], maxLines: Int) -> CGSize {
            let font = attrs[.font] as! NSFont
            let lineH = ceil(font.ascender - font.descender + font.leading)
            let maxH = lineH * CGFloat(max(1, maxLines))
            let r = (s as NSString).boundingRect(with: NSSize(width: width, height: maxH),
                                                 options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                                 attributes: attrs)
            return CGSize(width: min(width, ceil(r.width)), height: min(maxH, ceil(r.height)))
        }

        override func draw(_ dirtyRect: NSRect) {
            var y: CGFloat = 0
            if let primary {
                (primary as NSString).draw(with: NSRect(x: 0, y: y, width: bounds.width, height: primaryHeight),
                                           options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                           attributes: TextLayer.attrs(LabelView.appFont, LabelView.appColor, alignment))
                y += primaryHeight + LabelView.lineGap
            }
            if let secondary {
                (secondary as NSString).draw(with: NSRect(x: 0, y: y, width: bounds.width, height: secondaryHeight),
                                             options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                             attributes: TextLayer.attrs(LabelView.titleFont, LabelView.titleColor, alignment))
            }
        }
    }
}
