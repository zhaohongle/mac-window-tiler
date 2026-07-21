import Cocoa
import ApplicationServices

// MARK: - Window Manager

struct WindowLayout {
    let name: String
    let columns: Int
    let rows: Int
}

let layouts: [WindowLayout] = [
    WindowLayout(name: "2列", columns: 2, rows: 1),
    WindowLayout(name: "3列", columns: 3, rows: 1),
    WindowLayout(name: "4列", columns: 4, rows: 1),
    WindowLayout(name: "2×2宫格", columns: 2, rows: 2),
    WindowLayout(name: "3×2宫格", columns: 3, rows: 2),
    WindowLayout(name: "4×2宫格", columns: 4, rows: 2),
]

func getVisibleWindows(on screen: NSScreen) -> [(app: AXUIElement, window: AXUIElement)] {
    var results: [(app: AXUIElement, window: AXUIElement)] = []

    let runningApps = NSWorkspace.shared.runningApplications.filter {
        $0.activationPolicy == .regular && !$0.isHidden
    }

    for app in runningApps {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { continue }

        for window in windows {
            // Skip minimized windows
            var minimizedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef) == .success,
               let minimized = minimizedRef as? Bool, minimized { continue }

            // Skip windows not on this screen
            if let frame = getWindowFrame(window) {
                let windowCenter = CGPoint(x: frame.midX, y: frame.midY)
                // Convert from screen coordinates (flipped) to AppKit
                let flippedY = NSScreen.screens.first!.frame.height - windowCenter.y
                let appKitPoint = CGPoint(x: windowCenter.x, y: flippedY)
                if screen.frame.contains(appKitPoint) {
                    results.append((app: axApp, window: window))
                }
            }
        }
    }
    return results
}

func getWindowFrame(_ window: AXUIElement) -> CGRect? {
    var positionRef: CFTypeRef?
    var sizeRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
          AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else { return nil }

    var position = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
    AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
    return CGRect(origin: position, size: size)
}

func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
    var position = frame.origin
    var size = frame.size
    if let posVal = AXValueCreate(.cgPoint, &position) {
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
    }
    if let sizeVal = AXValueCreate(.cgSize, &size) {
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
    }
}

func tileWindows(layout: WindowLayout) {
    guard let screen = NSScreen.main else { return }

    let screenFrame = screen.visibleFrame // excludes menu bar and dock
    // Convert AppKit coordinates (bottom-left origin) to CGPoint (top-left origin) for AX API
    let screenTop = NSScreen.screens.first!.frame.height - screenFrame.maxY
    let axFrame = CGRect(x: screenFrame.minX, y: screenTop, width: screenFrame.width, height: screenFrame.height)

    let windowPairs = getVisibleWindows(on: screen)
    guard !windowPairs.isEmpty else { return }

    let cols = layout.columns
    let rows = layout.rows
    let totalSlots = cols * rows

    let cellWidth = axFrame.width / CGFloat(cols)
    let cellHeight = axFrame.height / CGFloat(rows)

    for (index, pair) in windowPairs.enumerated() {
        let slot = index % totalSlots
        let col = slot % cols
        let row = slot / cols

        let x = axFrame.minX + CGFloat(col) * cellWidth
        let y = axFrame.minY + CGFloat(row) * cellHeight

        let targetFrame = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
        setWindowFrame(pair.window, frame: targetFrame)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            showPermissionAlert()
        }

        setupMenuBar()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "Window Tiler")
            button.toolTip = "Window Tiler"
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "一键排列", action: nil, keyEquivalent: ""))

        for layout in layouts {
            let item = NSMenuItem(title: "  " + layout.name, action: #selector(applyLayout(_:)), keyEquivalent: "")
            item.representedObject = layout
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "刷新权限", action: #selector(checkPermission), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func applyLayout(_ sender: NSMenuItem) {
        guard let layout = sender.representedObject as? WindowLayout else { return }

        let trusted = AXIsProcessTrusted()
        if !trusted {
            showPermissionAlert()
            return
        }

        tileWindows(layout: layout)
    }

    @objc func checkPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "Window Tiler 需要辅助功能权限才能移动窗口。\n\n请前往：系统设置 → 隐私与安全性 → 辅助功能，将本应用加入列表并启用。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // no Dock icon
app.run()
