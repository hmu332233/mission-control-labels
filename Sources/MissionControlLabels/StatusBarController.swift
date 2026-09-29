import AppKit
import MissionControlLabelsCore

final class StatusBarController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
    private let permissionItem = NSMenuItem(title: "", action: #selector(openPermission), keyEquivalent: "")
    private let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let diagItem = NSMenuItem(title: L10n.string("menu.diagnostics.record", "Record Next Mission Control Diagnostics"), action: #selector(armDiagnostics), keyEquivalent: "")

    private let anchorMenu = NSMenu()
    var anchor: LabelAnchor = .default
    var onAnchorChange: ((LabelAnchor) -> Void)?
    private let orderMenu = NSMenu()
    var order: LabelOrder = .default
    var onOrderChange: ((LabelOrder) -> Void)?
    private let iconLayoutMenu = NSMenu()
    var iconLayout: LabelIconLayout = .default
    var onIconLayoutChange: ((LabelIconLayout) -> Void)?
    private let scaleMenu = NSMenu()
    var scale: LabelScale = .default
    var onScaleChange: ((LabelScale) -> Void)?
    private let showAppIconItem = NSMenuItem(title: L10n.string("menu.icon.show", "Show App Icon"), action: #selector(toggleShowAppIcon), keyEquivalent: "")
    var showAppIcon = false
    var onShowAppIconChange: ((Bool) -> Void)?
    var isEnabled = true
    var isTrusted = false
    var stateText = ""
    var onToggle: ((Bool) -> Void)?
    var onArmDiagnostics: (() -> Void)?

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let img = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "Mission Control Labels") {
            img.isTemplate = true
            item.button?.image = img
        } else {
            item.button?.title = "MC"
        }
        for mi in [toggleItem, permissionItem, diagItem, showAppIconItem] { mi.target = self }
        stateItem.isEnabled = false
        menu.addItem(toggleItem)
        menu.addItem(stateItem)
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        let anchorItem = NSMenuItem(title: L10n.string("menu.label.position", "Label Position"), action: nil, keyEquivalent: "")
        for a in LabelAnchor.allCases {
            let mi = NSMenuItem(title: L10n.string(a.localizationKey, a.displayName), action: #selector(selectAnchor(_:)), keyEquivalent: "")
            mi.representedObject = a.rawValue
            mi.target = self
            anchorMenu.addItem(mi)
        }
        anchorItem.submenu = anchorMenu
        menu.addItem(anchorItem)
        let orderItem = NSMenuItem(title: L10n.string("menu.label.order", "Info Order"), action: nil, keyEquivalent: "")
        for o in LabelOrder.allCases {
            let mi = NSMenuItem(title: L10n.string(o.localizationKey, o.displayName), action: #selector(selectOrder(_:)), keyEquivalent: "")
            mi.representedObject = o.rawValue
            mi.target = self
            orderMenu.addItem(mi)
        }
        orderItem.submenu = orderMenu
        menu.addItem(orderItem)
        let iconLayoutItem = NSMenuItem(title: "Icon Position", action: nil, keyEquivalent: "")
        for l in LabelIconLayout.allCases {
            let mi = NSMenuItem(title: l.displayName, action: #selector(selectIconLayout(_:)), keyEquivalent: "")
            mi.representedObject = l.rawValue
            mi.target = self
            iconLayoutMenu.addItem(mi)
        }
        iconLayoutItem.submenu = iconLayoutMenu
        menu.addItem(iconLayoutItem)
        let scaleItem = NSMenuItem(title: "Label Size", action: nil, keyEquivalent: "")
        for s in LabelScale.allCases {
            let mi = NSMenuItem(title: s.displayName, action: #selector(selectScale(_:)), keyEquivalent: "")
            mi.representedObject = s.rawValue
            mi.target = self
            scaleMenu.addItem(mi)
        }
        scaleItem.submenu = scaleMenu
        menu.addItem(scaleItem)
        menu.addItem(showAppIconItem)
        menu.addItem(.separator())
        menu.addItem(diagItem)
        menu.addItem(withTitle: L10n.string("menu.diagnostics.openFolder", "Open Diagnostics Log Folder"), action: #selector(openLogs), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.string("menu.quit", "Quit"), action: #selector(quit), keyEquivalent: "q").target = self
        menu.delegate = self
        item.menu = menu
        refresh()
    }

    func refresh() {
        toggleItem.title = isEnabled ? L10n.string("menu.toggle.hide", "Hide Labels") : L10n.string("menu.toggle.show", "Show Labels")
        toggleItem.state = isEnabled ? .on : .off
        permissionItem.title = isTrusted ? L10n.string("menu.permission.granted", "Accessibility Permission: Granted") : L10n.string("menu.permission.required", "Accessibility Permission Required — Open System Settings…")
        stateItem.title = L10n.string("menu.state", "State: %@", stateText)
        for mi in anchorMenu.items { mi.state = (mi.representedObject as? String) == anchor.rawValue ? .on : .off }
        for mi in orderMenu.items { mi.state = (mi.representedObject as? String) == order.rawValue ? .on : .off }
        for mi in iconLayoutMenu.items { mi.state = (mi.representedObject as? String) == iconLayout.rawValue ? .on : .off }
        for mi in scaleMenu.items { mi.state = (mi.representedObject as? String) == scale.rawValue ? .on : .off }
        showAppIconItem.state = showAppIcon ? .on : .off
        item.button?.appearsDisabled = !(isEnabled && isTrusted)
    }

    func menuNeedsUpdate(_ menu: NSMenu) { refresh() }

    @objc private func toggle() {
        isEnabled.toggle()
        refresh()
        onToggle?(isEnabled)
    }

    @objc private func openPermission() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func selectAnchor(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let a = LabelAnchor(rawValue: raw) else { return }
        anchor = a
        refresh()
        onAnchorChange?(a)
    }

    @objc private func selectOrder(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let o = LabelOrder(rawValue: raw) else { return }
        order = o
        refresh()
        onOrderChange?(o)
    }

    @objc private func toggleShowAppIcon() {
        showAppIcon.toggle()
        refresh()
        onShowAppIconChange?(showAppIcon)
    }

    @objc private func selectIconLayout(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let l = LabelIconLayout(rawValue: raw) else { return }
        iconLayout = l
        // 아이콘 위치를 고른 건 아이콘을 보겠다는 뜻이므로 켜져 있지 않으면 켠다
        if !showAppIcon {
            showAppIcon = true
            onShowAppIconChange?(true)
        }
        refresh()
        onIconLayoutChange?(l)
    }

    @objc private func selectScale(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let s = LabelScale(rawValue: raw) else { return }
        scale = s
        refresh()
        onScaleChange?(s)
    }

    @objc private func armDiagnostics() { onArmDiagnostics?() }

    @objc private func openLogs() {
        let dir = Diagnostics.logDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
