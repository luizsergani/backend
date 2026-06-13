import AppKit
import Combine

/// Monitora a área de transferência e mantém um histórico dos últimos textos
/// copiados (deduplicado, mais recente primeiro), persistido entre reinícios.
final class ClipboardManager: ObservableObject {
    static let maxItems = 20
    private static let storageKey = "clipboardHistory"

    @Published private(set) var history: [String] = []

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        lastChangeCount = pasteboard.changeCount
        history = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let text = pasteboard.string(forType: .string) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        record(text)
    }

    /// Insere/promove um item no topo do histórico.
    func record(_ text: String) {
        var items = history.filter { $0 != text }
        items.insert(text, at: 0)
        if items.count > Self.maxItems { items = Array(items.prefix(Self.maxItems)) }
        history = items
        UserDefaults.standard.set(items, forKey: Self.storageKey)
    }

    func clear() {
        history = []
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    /// Marca o changeCount atual como "já visto", para que um copy feito pelo
    /// próprio painel não seja recapturado de forma duplicada.
    func acknowledgeChange() {
        lastChangeCount = pasteboard.changeCount
    }
}
