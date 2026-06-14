import AppKit
import CoreGraphics

/// Atalho global via CGEvent tap: captura a combinação de teclas ANTES de
/// qualquer app vê-la — imune a atalhos de menu (ex.: "Colar e Manter Estilo"
/// em ⌥⌘V) e a teclas que apps em foco consomem. Requer a permissão de
/// Acessibilidade (já pedida no launch). Reativa-se sozinho se o sistema
/// desligar o tap sob carga.
final class EventTapHotKey {
    private let keyCode: CGKeyCode
    private let modifiers: CGEventFlags
    private let callback: () -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    init(keyCode: CGKeyCode, modifiers: CGEventFlags, callback: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.callback = callback
        install()
    }

    /// true se o tap foi criado (Acessibilidade concedida).
    var isActive: Bool { tap != nil }

    private func install() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userData -> Unmanaged<CGEvent>? in
                guard let userData else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<EventTapHotKey>.fromOpaque(userData).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let t = me.tap { CGEvent.tapEnable(tap: t, enable: true) }
                    return Unmanaged.passUnretained(event)
                }

                if type == .keyDown {
                    let kc = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                    let relevant: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
                    let flags = event.flags.intersection(relevant)
                    if kc == me.keyCode && flags == me.modifiers {
                        DispatchQueue.main.async { me.callback() }
                        return nil // consome o evento (não chega no app)
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            return
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = src
    }

    deinit {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
    }
}
