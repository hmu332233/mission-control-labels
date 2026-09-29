import AppKit
import MissionControlLabelsCore

/// 1줄 주 정보(창 제목·워크스페이스, 최대 2줄)와 2줄 보조 정보(앱 이름, 1줄)를 반투명 글래스 카드 위에 그리는 라벨
/// 옵션: 앱 아이콘을 텍스트 안 줄에(기본) 또는 카드 왼쪽 별도 칸에 세로 중앙으로, 그리고 전체 배율
/// 디자인 근거: design/spec.md 시안 A(카드). 배경은 뒤 화면과 무관한 고정 단색
final class LabelView: NSView {
    static let appColor = NSColor.white
    static let titleColor = NSColor.white.withAlphaComponent(0.78)
    /// 카드 배경. 블러·비침 없이 어디서나 동일 색으로 보이도록 거의 불투명한 어두운 회색 사용
    static let cardBackground = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 0.92)
    static let border = NSColor.white.withAlphaComponent(0.18)

    /// 시안 A 기준 치장에 배율을 곱한 값. 100%는 시안과 동일한 값
    struct Style {
        let scale: CGFloat

        init(_ scale: LabelScale) { self.scale = scale.factor }

        var appFont: NSFont { NSFont.systemFont(ofSize: 15 * scale, weight: .semibold) }
        var titleFont: NSFont { NSFont.systemFont(ofSize: 13 * scale, weight: .regular) }
        var paddingH: CGFloat { 16 * scale }
        var paddingV: CGFloat { 11 * scale }
        var lineGap: CGFloat { 3 * scale }
        var cornerRadius: CGFloat { 14 * scale }
        var iconGap: CGFloat { 6 * scale }
        /// 왼쪽 별도 칸 아이콘: 텍스트보다 크게, 카드 세로 중앙. 모든 라벨에서 같고, 칸 폭도 이 기준으로 고정
        var leadingIconSide: CGFloat { 44 * scale }
        /// 낮은 카드에서는 아이콘이 카드 밖으로 넘치지 않도록 이 이상으로 키우지 않는다
        func maxLeadingIconSide(_ cardHeight: CGFloat) -> CGFloat { max(16, cardHeight - paddingV * 1.2) }
    }

    private let style: Style
    private let text: TextLayer
    private let iconView: IconView?

    init(label: ResolvedLabel,
         maxWidth: CGFloat,
         titleLineLimit: Int,
         alignment: LabelAnchor.TextAlignment = .center,
         order: LabelOrder = .default,
         icon: NSImage? = nil,
         iconLayout: LabelIconLayout = .default,
         scale: LabelScale = .default) {
        let style = Style(scale)
        self.style = style
        // 왼쪽 칸 배치에서는 아이콘이 텍스트 밖으로 나오므로 텍스트에는 넘기지 않는다
        let useLeadingCell = iconLayout == .leading && icon != nil
        let iconColumn: CGFloat = useLeadingCell ? style.leadingIconSide + style.iconGap * 2 : 0
        // 아이콘을 왼쪽 칸에 두면 텍스트 칸은 좌측 정렬이 자연스럽다
        let textAlignment = Self.nsAlignment(useLeadingCell ? .left : alignment)

        // 폭 상한은 썸네일(= 실창 비율)에서 나오는 값 하나뿐. 안에 별도의 상한을 두면 긴 제목이
        // 자리가 남는데도 말줄임으로 잘렸다. 넓어질 만큼 넓히고 남는 곳에서만 줄바꿈·말줄임
        let cardMax = maxWidth
        text = TextLayer(label: label,
                         textWidth: max(24, cardMax - style.paddingH * 2 - iconColumn),
                         titleLineLimit: titleLineLimit,
                         alignment: textAlignment,
                         order: order,
                         icon: useLeadingCell ? nil : icon,
                         style: style)
        iconView = useLeadingCell ? icon.map { IconView(image: $0) } : nil

        // 카드 높이는 텍스트와 아이콘 중 큰 값에 여백을 더한다. 아이콘 크기를 라벨마다 다르게 줄이면
        // (한 줄짜리 라벨은 카드가 낮다) 같은 화면에서 크게·작게 섞여 보이므로 카드 쪽을 키운다
        let contentHeight = max(text.contentSize.height, useLeadingCell ? style.leadingIconSide : 0)
        let size = NSSize(width: min(cardMax, ceil(iconColumn + text.contentSize.width)) + style.paddingH * 2,
                          height: contentHeight + style.paddingV * 2)
        super.init(frame: NSRect(origin: .zero, size: size))
        wantsLayer = true
        // 시안 A: 패널 그림자 x0 / y4 / blur16 / 검정 16%
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        self.shadow = shadow

        let background = Self.makeBackground(frame: bounds, cornerRadius: style.cornerRadius)
        background.autoresizingMask = [.width, .height]
        addSubview(background)

        let borderView = BorderView(frame: bounds, cornerRadius: style.cornerRadius)
        borderView.autoresizingMask = [.width, .height]
        addSubview(borderView)

        if let iconView { addSubview(iconView) }
        addSubview(text)
        layoutContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 아이콘·텍스트 위치. 모든 라벨에서 아이콘 한 변은 같은 값이고, 카드가 세로로 잘릴 때만 줄어든다
    private func layoutContent() {
        let iconSide: CGFloat = iconView == nil ? 0 : min(style.leadingIconSide, max(16, style.maxLeadingIconSide(bounds.height)))
        let column = iconView == nil ? 0 : style.leadingIconSide + style.iconGap * 2
        iconView?.frame = NSRect(x: round(style.paddingH + (style.leadingIconSide - iconSide) / 2),
                                 y: round((bounds.height - iconSide) / 2),
                                 width: round(iconSide),
                                 height: round(iconSide))
        // 왼쪽 칸 배치에서는 세로 중앙에, 그 외에는 위쪽 여백부터 채운다(시안 A와 동일)
        let textY = iconView == nil ? style.paddingV : max(style.paddingV, (bounds.height - text.contentSize.height) / 2)
        text.frame = NSRect(x: round(style.paddingH + column),
                            y: round(textY),
                            width: max(0, bounds.width - round(style.paddingH * 2 + column)),
                            height: max(0, bounds.height - round(textY * 2)))
    }

    /// 썸네일 높이에 맞춰 카드가 잘려도 아이콘과 텍스트가 제자리를 찾는다
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutContent()
    }

    private static func nsAlignment(_ alignment: LabelAnchor.TextAlignment) -> NSTextAlignment {
        switch alignment {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

    private static func makeBackground(frame: NSRect, cornerRadius: CGFloat) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true
        v.layer?.backgroundColor = cardBackground.cgColor
        v.layer?.cornerRadius = cornerRadius
        v.layer?.cornerCurve = .continuous
        return v
    }

    private final class BorderView: NSView {
        private let cornerRadius: CGFloat

        init(frame: NSRect, cornerRadius: CGFloat) {
            self.cornerRadius = cornerRadius
            super.init(frame: frame)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func draw(_ dirtyRect: NSRect) {
            // 물리 1px 테두리(Retina 2×에서 0.5pt)
            let scale = window?.backingScaleFactor ?? 2
            let w = 1 / scale
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: w / 2, dy: w / 2),
                                    xRadius: cornerRadius, yRadius: cornerRadius)
            LabelView.border.setStroke()
            path.lineWidth = w
            path.stroke()
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    /// 카드 왼쪽 칸의 앱 아이콘. 텍스트와 독립적으로 세로 중앙에 놓인다
    private final class IconView: NSView {
        private let image: NSImage

        init(image: NSImage) {
            self.image = image
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func draw(_ dirtyRect: NSRect) {
            image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1,
                       respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    /// 텍스트 측정·그리기. 정렬은 인자로 넘긴 값, 마지막 줄 말줄임. 인라인 아이콘은 해당 줄 앞에 같은 줄로 배치
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
        let style: Style

        init(label: ResolvedLabel, textWidth: CGFloat, titleLineLimit: Int, alignment: NSTextAlignment,
             order: LabelOrder, icon: NSImage?, style: Style) {
            self.alignment = alignment
            self.style = style
            let lines = label.displayLines(order: order)
            primary = lines.primary
            secondary = titleLineLimit > 0 ? lines.secondary : nil
            self.icon = icon
            // 앱 이름이 있는 줄에 아이콘 배치. 한 줄뿐이면 그 줄
            iconLine = (secondary == nil || order == .appFirst) ? .primary : .secondary
            let appFont = style.appFont, titleFont = style.titleFont
            iconSide = icon != nil ? TextLayer.lineHeight(iconLine == .primary ? appFont : titleFont) : 0
            let iconReserve = icon != nil ? iconSide + style.iconGap : 0

            var pw: CGFloat = 0, ph: CGFloat = 0, sw: CGFloat = 0, sh: CGFloat = 0
            if let p = primary {
                let w = textWidth - (iconLine == .primary ? iconReserve : 0)
                let r = TextLayer.measure(p, width: w, attrs: TextLayer.attrs(appFont, LabelView.appColor), maxLines: max(1, titleLineLimit))
                pw = r.width; ph = r.height
            }
            if let s = secondary {
                let w = textWidth - (iconLine == .secondary ? iconReserve : 0)
                let r = TextLayer.measure(s, width: w, attrs: TextLayer.attrs(titleFont, LabelView.titleColor), maxLines: 1)
                sw = r.width; sh = r.height
            }
            primaryWidth = pw
            primaryHeight = ph
            secondaryWidth = sw
            secondaryHeight = sh
            let primaryGroup = pw + (iconLine == .primary ? iconReserve : 0)
            let secondaryGroup = sw + (iconLine == .secondary ? iconReserve : 0)
            let gap: CGFloat = (primary != nil && secondary != nil) ? style.lineGap : 0
            contentSize = CGSize(width: ceil(max(primaryGroup, secondaryGroup)), height: ceil(ph + sh + gap))
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }
        override var isFlipped: Bool { true }

        static func lineHeight(_ font: NSFont) -> CGFloat {
            if let cached = lineHeightCache[font] { return cached }
            // ascender-descender+leading 식은 15pt에서 18pt를 주는데 실제로 한 줄은 19pt를
            // 차지한다. 그래서 "두 줄 허용" = 36pt에 실제 두 줄이 안 들어가 긴 제목이 항상
            // 한 줄로 잘렸다. 줄 높이는 수식으로 계산하지 않고 위아래로 튀는 문자가 있는
            // 문자열을 재서 얻는다. LabelView는 메인 스레드에서만 만들므로 락이 필요 없다
            let measured = ceil(("Hxpg" as NSString)
                .boundingRect(with: NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude),
                              options: [.usesLineFragmentOrigin],
                              attributes: [.font: font])
                .height)
            lineHeightCache[font] = measured
            return measured
        }

        private static var lineHeightCache: [NSFont: CGFloat] = [:]

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
            let appFont = style.appFont, titleFont = style.titleFont
            var y: CGFloat = 0
            if let primary {
                drawLine(primary, y: y, textWidth: primaryWidth, height: primaryHeight,
                         attrs: TextLayer.attrs(appFont, LabelView.appColor, alignment), withIcon: iconLine == .primary)
                y += primaryHeight + style.lineGap
            }
            if let secondary {
                drawLine(secondary, y: y, textWidth: secondaryWidth, height: secondaryHeight,
                         attrs: TextLayer.attrs(titleFont, LabelView.titleColor, alignment), withIcon: iconLine == .secondary)
            }
        }

        /// 아이콘이 없으면 전체 폭에 정렬대로 그리고, 있으면 아이콘+텍스트 묶음을 정렬 위치에 배치
        private func drawLine(_ s: String, y: CGFloat, textWidth: CGFloat, height: CGFloat, attrs: [NSAttributedString.Key: Any], withIcon: Bool) {
            guard withIcon, let icon else {
                (s as NSString).draw(with: NSRect(x: 0, y: y, width: bounds.width, height: height),
                                     options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attrs)
                return
            }
            let groupWidth = iconSide + style.iconGap + textWidth
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
            (s as NSString).draw(with: NSRect(x: round(x0) + iconSide + style.iconGap, y: y, width: textWidth, height: height),
                                 options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: leftAttrs)
        }
    }
}
