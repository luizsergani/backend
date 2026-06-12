import AppKit
import AVFoundation
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum State { case idle, recording, transcribing }

    private var statusItem: NSStatusItem!
    private let recorder = Recorder()
    private let transcriber = Transcriber()
    private var hotKey: HotKey?
    private var state: State = .idle
    private var lastText = ""

    private var language: String {
        get { UserDefaults.standard.string(forKey: "language") ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: "language") }
    }

    private var autoPaste: Bool {
        get { UserDefaults.standard.object(forKey: "autoPaste") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoPaste") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Sussurro")
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Sussurro — clique ou ⌥⌘D para gravar"
        }

        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
            self?.toggle()
        }

        AVCaptureDevice.requestAccess(for: .audio) { _ in }

        // Pede a permissão de Acessibilidade já na primeira execução,
        // para o auto-colar (⌘V sintético) funcionar quando for usado.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @objc private func statusClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            statusItem.menu = buildMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggle()
        }
    }

    @objc private func toggle() {
        switch state {
        case .idle: startRecording()
        case .recording: stopAndTranscribe()
        case .transcribing: break
        }
    }

    private func startRecording() {
        do {
            try recorder.start()
        } catch {
            showError("Não consegui acessar o microfone.\n\n\(error.localizedDescription)\n\nVerifique em Ajustes do Sistema → Privacidade e Segurança → Microfone se o Sussurro está autorizado.")
            return
        }
        state = .recording
        setIcon("record.circle.fill", tint: .systemRed)
        NSSound(named: "Pop")?.play()
    }

    private func stopAndTranscribe() {
        guard let wav = recorder.stop() else {
            state = .idle
            setIcon("mic", tint: nil)
            return
        }
        state = .transcribing
        setIcon("hourglass", tint: nil)
        NSSound(named: "Bottle")?.play()

        let lang = language
        let paste = autoPaste
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer { try? FileManager.default.removeItem(at: wav) }
            do {
                let text = try self?.transcriber.transcribe(wav: wav, language: lang) ?? ""
                DispatchQueue.main.async { self?.finish(text: text, paste: paste) }
            } catch {
                DispatchQueue.main.async {
                    self?.state = .idle
                    self?.setIcon("mic", tint: nil)
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }

    private func finish(text: String, paste: Bool) {
        state = .idle
        setIcon("mic", tint: nil)
        guard !text.isEmpty else {
            NSSound(named: "Basso")?.play()
            return
        }
        lastText = text
        Paster.copy(text)
        if paste { Paster.paste() }
        NSSound(named: "Glass")?.play()
    }

    private func setIcon(_ symbol: String, tint: NSColor?) {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Sussurro")
        button.contentTintColor = tint
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let toggleTitle = state == .recording ? "Parar e transcrever" : "Iniciar gravação"
        let toggleItem = NSMenuItem(title: "\(toggleTitle)  ⌥⌘D", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.isEnabled = state != .transcribing
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let langMenu = NSMenu()
        for (title, code) in [("Automático", "auto"), ("Português", "pt"), ("Inglês", "en")] {
            let item = NSMenuItem(title: title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = code
            item.state = language == code ? .on : .off
            langMenu.addItem(item)
        }
        let langItem = NSMenuItem(title: "Idioma", action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)

        let pasteItem = NSMenuItem(title: "Colar automaticamente (⌘V)", action: #selector(toggleAutoPaste), keyEquivalent: "")
        pasteItem.target = self
        pasteItem.state = autoPaste ? .on : .off
        menu.addItem(pasteItem)

        let copyItem = NSMenuItem(title: "Copiar última transcrição", action: #selector(copyLast), keyEquivalent: "")
        copyItem.target = self
        copyItem.isEnabled = !lastText.isEmpty
        menu.addItem(copyItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Sair do Sussurro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        if let code = sender.representedObject as? String {
            language = code
        }
    }

    @objc private func toggleAutoPaste() {
        autoPaste.toggle()
    }

    @objc private func copyLast() {
        Paster.copy(lastText)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Sussurro"
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
