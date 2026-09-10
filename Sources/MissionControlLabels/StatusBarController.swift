import AppKit
import MissionControlLabelsCore

/// 메뉴바 항목: 켜기·끄기, 권한 안내, 진단, 종료.
final class StatusBarController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
    private let permissionItem = NSMenuItem(title: "", action: #selector(openPermission), keyEquivalent: "")
    private let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let diagItem = NSMenuItem(title: "다음 Mission Control 진단 기록", action: #selector(armDiagnostics), keyEquivalent: "")

    private let anchorMenu = NSMenu()
    var anchor: LabelAnchor = .default
    var onAnchorChange: ((LabelAnchor) -> Void)?
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
        for mi in [toggleItem, permissionItem, diagItem] { mi.target = self }
        stateItem.isEnabled = false
        menu.addItem(toggleItem)
        menu.addItem(stateItem)
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        let anchorItem = NSMenuItem(title: "라벨 위치", action: nil, keyEquivalent: "")
        for a in LabelAnchor.allCases {
            let mi = NSMenuItem(title: a.displayName, action: #selector(selectAnchor(_:)), keyEquivalent: "")
            mi.representedObject = a.rawValue
            mi.target = self
            anchorMenu.addItem(mi)
        }
        anchorItem.submenu = anchorMenu
        menu.addItem(anchorItem)
        menu.addItem(.separator())
        menu.addItem(diagItem)
        menu.addItem(withTitle: "진단 로그 폴더 열기", action: #selector(openLogs), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "종료", action: #selector(quit), keyEquivalent: "q").target = self
        menu.delegate = self
        item.menu = menu
        refresh()
    }

    func refresh() {
        toggleItem.title = isEnabled ? "라벨 표시 끄기" : "라벨 표시 켜기"
        toggleItem.state = isEnabled ? .on : .off
        permissionItem.title = isTrusted ? "손쉬운 사용 권한: 허용됨" : "손쉬운 사용 권한 필요 — 시스템 설정 열기…"
        stateItem.title = "상태: \(stateText)"
        for mi in anchorMenu.items { mi.state = (mi.representedObject as? String) == anchor.rawValue ? .on : .off }
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

    @objc private func armDiagnostics() { onArmDiagnostics?() }

    @objc private func openLogs() {
        let dir = Diagnostics.logDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
