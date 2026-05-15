import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: TiqPanel!
    private let store = TaskStore()
    private var clickMonitor: Any?
    private var escMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupEditMenu()
        setupStatusItem()
        setupPanel()
        applyAppearance()
        let shortcutRegistered = GlobalShortcutManager.shared.register { [weak self] in
            self?.togglePanel()
        }
        statusItem.button?.toolTip = shortcutRegistered
            ? "Tiqdo - Ctrl+Q"
            : "Tiqdo - Ctrl+Q shortcut could not be registered"
        NotificationCenter.default.addObserver(
            self, selector: #selector(appearanceDidChange),
            name: .tiqDoAppearanceChanged, object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flushPendingSave()
        removeEventMonitors()
        GlobalShortcutManager.shared.unregister()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appearanceDidChange() {
        applyAppearance()
    }

    private func applyAppearance() {
        let mode = store.appearanceMode
        panel.appearance = mode.nsAppearance
        panel.backgroundColor = Theme.nsBg(for: mode)
    }

    // MARK: - Edit Menu (enables Cmd+Z, Cmd+C, etc. in LSUIElement apps)

    private func setupEditMenu() {
        let mainMenu = NSMenu()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.image = makeIcon()
        button.action = #selector(togglePanel)
        button.target = self
    }

    private func makeIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset: CGFloat = 1.5
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: inset, dy: inset))
            circle.lineWidth = 1.3
            NSColor.black.setStroke()
            circle.stroke()

            let check = NSBezierPath()
            check.move(to: NSPoint(x: 5.5, y: 8.5))
            check.line(to: NSPoint(x: 8, y: 5.5))
            check.line(to: NSPoint(x: 12.5, y: 12))
            check.lineWidth = 1.6
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            NSColor.black.setStroke()
            check.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Panel

    private func setupPanel() {
        let contentView = PopoverView()
            .environment(store)

        panel = TiqPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.contentViewController = NSHostingController(rootView: contentView)
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .floating
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = NSColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1)
        panel.isMovableByWindowBackground = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.minSize = NSSize(width: 280, height: 320)
        panel.maxSize = NSSize(width: 500, height: 800)
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        removeEventMonitors()
        restorePanelSize()
        let origin = panelOrigin(panelSize: panel.frame.size)
        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panel.isVisible else { return }
            let loc = event.locationInWindow
            if !self.panel.frame.contains(loc) {
                self.hidePanel()
            }
        }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                if let self, self.store.editingTaskId != nil {
                    self.store.editingTaskId = nil
                    return nil
                }
                if let responder = self?.panel.firstResponder,
                   responder is NSTextView || responder is NSTextField {
                    return event
                }
                self?.hidePanel()
                return nil
            }
            if event.keyCode == 48 && event.modifierFlags.contains(.control) {
                self?.store.cycleTab()
                return nil
            }
            return event
        }
    }

    private func hidePanel() {
        savePanelSize()
        panel.orderOut(nil)
        removeEventMonitors()
    }

    private func removeEventMonitors() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
    }

    private let sizeKey = "tiqdo.panelSize"

    private func savePanelSize() {
        let size = panel.frame.size
        UserDefaults.standard.set([Double(size.width), Double(size.height)], forKey: sizeKey)
    }

    private func restorePanelSize() {
        if let arr = UserDefaults.standard.array(forKey: sizeKey) as? [Double], arr.count == 2 {
            let w = max(panel.minSize.width, min(panel.maxSize.width, arr[0]))
            let h = max(panel.minSize.height, min(panel.maxSize.height, arr[1]))
            panel.setContentSize(NSSize(width: w, height: h))
        }
    }

    private func panelOrigin(panelSize: NSSize) -> NSPoint {
        if let button = statusItem.button,
           let bw = button.window,
           bw.isVisible {
            let sf = bw.convertToScreen(button.convert(button.bounds, to: nil))
            if sf.width > 0 {
                let screen = bw.screen ?? screen(containing: sf) ?? NSScreen.main
                let desired = NSPoint(
                    x: sf.midX - panelSize.width / 2,
                    y: sf.minY - panelSize.height - 4
                )
                if let screen {
                    return clampedPanelOrigin(desired, panelSize: panelSize, visibleFrame: screen.visibleFrame)
                }
                return desired
            }
        }
        guard let screen = NSScreen.main else { return .zero }
        let desired = NSPoint(
            x: screen.visibleFrame.maxX - panelSize.width - 16,
            y: screen.visibleFrame.maxY - panelSize.height - 8
        )
        return clampedPanelOrigin(desired, panelSize: panelSize, visibleFrame: screen.visibleFrame)
    }

    private func screen(containing rect: NSRect) -> NSScreen? {
        NSScreen.screens.max { lhs, rhs in
            lhs.frame.intersection(rect).area < rhs.frame.intersection(rect).area
        }
    }

    private func clampedPanelOrigin(_ origin: NSPoint, panelSize: NSSize, visibleFrame: NSRect) -> NSPoint {
        let padding: CGFloat = 8
        let minX = visibleFrame.minX + padding
        let maxX = max(minX, visibleFrame.maxX - panelSize.width - padding)
        let minY = visibleFrame.minY + padding
        let maxY = max(minY, visibleFrame.maxY - panelSize.height - padding)
        return NSPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }
}

private extension NSRect {
    var area: CGFloat {
        guard !isNull && !isEmpty else { return 0 }
        return width * height
    }
}

final class TiqPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown,
           firstResponder is NSTextView,
           let hit = contentView?.hitTest(event.locationInWindow),
           !(hit is NSTextView),
           !(hit is NSTextField) {
            makeFirstResponder(nil)
        }
        super.sendEvent(event)
    }
}
