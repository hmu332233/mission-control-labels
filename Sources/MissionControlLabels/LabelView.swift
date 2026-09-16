import AppKit
import MissionControlLabelsCore

/// 1줄 주 정보(창 제목·워크스페이스, 최대 2줄)와 2줄 보조 정보(앱 이름, 1줄)를 반투명 글래스 카드 위에 중앙 정렬로 그리는 라벨
/// 옵션으로 앱 이름 줄 앞에 앱 아이콘을 같은 줄에 나란히 표시
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
    /// 아이콘과 같은 줄 텍스트 사이 간격
    static let iconGap: CGFloat = 6

    private let text: TextLayer

    init(label: ResolvedLabel, maxWidth: CGFloat, titleLineLimit: Int, alignment: LabelAnchor.TextAlignment = .center, order: LabelOrder = .default, icon: NSImage? = nil) {
        let cardMax = min(maxWidth, Self.maxCardWidth)
        text = TextLayer(label: label, textWidth: max(24, cardMax - Self.paddingH * 2), titleLineLimit: titleLineLimit, alignment: alignment, order: order, icon: icon)
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

    /// 텍스트 측정·그리기. 중앙 정렬, 마지막 줄 말줄임. 아이콘은 앱 이름 줄 앞에 같은 줄로 배치
    private final class TextLayer: NSView {
        enum Line { case primary, secondary }

        let primary: String?
        let secondary: String?
        let primaryHeight: CGFloat
        let secondaryHeight: CGFloat
        let primaryWidth: CGFloat
        let secondaryWidth: CGFloat
        let contentSize: CGSize
        let alignment: NSTextAlignment
        let icon: NSImage?
        let iconLine: Line
        let iconSide: CGFloat

        init(label: ResolvedLabel, textWidth: CGFloat, titleLineLimit: Int, alignment: LabelAnchor.TextAlignment, order: LabelOrder, icon: NSImage?) {
            switch alignment {
            case .left: self.alignment = .left
            case .center: self.alignment = .center
            case .right: self.alignment = .right
            }
            let lines = label.displayLines(order: order)
            primary = lines.primary
            secondary = titleLineLimit > 0 ? lines.secondary : nil
            self.icon = icon
            // 앱 이름이 있는 줄에 아이콘 배치. 한 줄뿐이면 그 줄
            iconLine = (secondary == nil || order == .appFirst) ? .primary : .secondary
            let iconFont = iconLine == .primary ? LabelView.appFont : LabelView.titleFont
            iconSide = icon != nil ? TextLayer.lineHeight(iconFont) : 0
            let iconReserve = icon != nil ? iconSide + LabelView.iconGap : 0

            var pw: CGFloat = 0, ph: CGFloat = 0, sw: CGFloat = 0, sh: CGFloat = 0
            if let p = primary {
                let w = textWidth - (iconLine == .primary ? iconReserve : 0)
                let r = TextLayer.measure(p, width: w, attrs: TextLayer.attrs(LabelView.appFont, LabelView.appColor), maxLines: max(1, titleLineLimit))
                pw = r.width; ph = r.height
            }
            if let s = secondary {
                let w = textWidth - (iconLine == .secondary ? iconReserve : 0)
                let r = TextLayer.measure(s, width: w, attrs: TextLayer.attrs(LabelView.titleFont, LabelView.titleColor), maxLines: 1)
                sw = r.width; sh = r.height
            }
            primaryWidth = pw
            primaryHeight = ph
            secondaryWidth = sw
            secondaryHeight = sh
            let primaryGroup = pw + (iconLine == .primary ? iconReserve : 0)
            let secondaryGroup = sw + (iconLine == .secondary ? iconReserve : 0)
            let gap: CGFloat = (primary != nil && secondary != nil) ? LabelView.lineGap : 0
            contentSize = CGSize(width: ceil(max(primaryGroup, secondaryGroup)), height: ceil(ph + sh + gap))
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }
        override var isFlipped: Bool { true }

        static func lineHeight(_ font: NSFont) -> CGFloat {
            ceil(font.ascender - font.descender + font.leading)
        }

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
            let lineH = lineHeight(font)
            let maxH = lineH * CGFloat(max(1, maxLines))
            let r = (s as NSString).boundingRect(with: NSSize(width: width, height: maxH),
                                                 options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                                 attributes: attrs)
            return CGSize(width: min(width, ceil(r.width)), height: min(maxH, ceil(r.height)))
        }

        override func draw(_ dirtyRect: NSRect) {
            var y: CGFloat = 0
            if let primary {
                drawLine(primary, y: y, textWidth: primaryWidth, height: primaryHeight,
                         attrs: TextLayer.attrs(LabelView.appFont, LabelView.appColor, alignment), withIcon: iconLine == .primary)
                y += primaryHeight + LabelView.lineGap
            }
            if let secondary {
                drawLine(secondary, y: y, textWidth: secondaryWidth, height: secondaryHeight,
                         attrs: TextLayer.attrs(LabelView.titleFont, LabelView.titleColor, alignment), withIcon: iconLine == .secondary)
            }
        }

        /// 아이콘이 없으면 전체 폭에 정렬대로 그리고, 있으면 아이콘+텍스트 묶음을 정렬 위치에 배치
        private func drawLine(_ s: String, y: CGFloat, textWidth: CGFloat, height: CGFloat, attrs: [NSAttributedString.Key: Any], withIcon: Bool) {
            guard withIcon, let icon else {
                (s as NSString).draw(with: NSRect(x: 0, y: y, width: bounds.width, height: height),
                                     options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attrs)
                return
            }
            let groupWidth = iconSide + LabelView.iconGap + textWidth
            let x0: CGFloat
            switch alignment {
            case .left: x0 = 0
            case .right: x0 = bounds.width - groupWidth
            default: x0 = (bounds.width - groupWidth) / 2
            }
            // 줄 상자 중앙에 두면 글자보다 위로 떠 보임. 대소문자 혼합 텍스트의 시각적 중심(대문자·x-height 중심의 중간)에 맞춤
            // NSString 그리기의 기준선은 ascender를 정수로 올린 위치에 놓임
            let font = attrs[.font] as! NSFont
            let baseline = y + ceil(font.ascender)
            let visualCenter = baseline - (font.capHeight + font.xHeight) / 4
            // Retina 2×에서 정수 픽셀이 되도록 0.5pt 단위로 맞춤
            let iconTop = ((visualCenter - iconSide / 2) * 2).rounded() / 2
            let iconRect = NSRect(x: round(x0), y: iconTop, width: iconSide, height: iconSide)
            icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            var leftAttrs = attrs
            let ps = (attrs[.paragraphStyle] as! NSParagraphStyle).mutableCopy() as! NSMutableParagraphStyle
            ps.alignment = .left
            leftAttrs[.paragraphStyle] = ps
            (s as NSString).draw(with: NSRect(x: round(x0) + iconSide + LabelView.iconGap, y: y, width: textWidth, height: height),
                                 options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: leftAttrs)
        }
    }
}
