import AppKit
import SwiftUI

/// Painel flutuante que pode receber foco de teclado mesmo sem barra de título.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Controla o painel "Área de Transferência & Emojis" (⌥⌘V):
/// histórico de cópias + emojis. Ao escolher um item, cola no cursor do app
/// que estava em foco — reaproveitando o `Paster` já usado pela transcrição.
final class PanelController: NSObject, NSWindowDelegate {
    private let clipboard: ClipboardManager
    private var panel: KeyablePanel?
    private var previousApp: NSRunningApplication?
    private var escMonitor: Any?
    private var isPicking = false

    init(clipboard: ClipboardManager) {
        self.clipboard = clipboard
    }

    func toggle() {
        if let panel, panel.isVisible {
            close()
        } else {
            show()
        }
    }

    private func show() {
        previousApp = NSWorkspace.shared.frontmostApplication

        let view = PanelView(
            clipboard: clipboard,
            onPick: { [weak self] in self?.pick($0) },
            onClear: { [weak self] in self?.clipboard.clear() }
        )

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: view)
        panel.delegate = self
        positionNearCursor(panel)

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.close()
                return nil
            }
            return event
        }
    }

    private func positionNearCursor(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        var origin = NSPoint(x: mouse.x - 190, y: mouse.y - 460)
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - 380 - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - 460 - 8)
        panel.setFrameOrigin(origin)
    }

    private func pick(_ text: String) {
        isPicking = true
        clipboard.record(text)
        Paster.copy(text)
        clipboard.acknowledgeChange()
        closePanel()
        previousApp?.activate()
        // pequeno atraso para o foco voltar ao app de destino antes do ⌘V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            Paster.paste()
            self.isPicking = false
        }
    }

    private func close() {
        closePanel()
        previousApp?.activate()
    }

    private func closePanel() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        escMonitor = nil
        panel?.orderOut(nil)
        panel = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        // fecha ao clicar fora — exceto durante a própria seleção
        guard !isPicking else { return }
        DispatchQueue.main.async { [weak self] in self?.closePanel() }
    }
}
