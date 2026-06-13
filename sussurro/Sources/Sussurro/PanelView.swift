import SwiftUI

/// Catálogo curado de emojis e símbolos por categoria (acesso rápido aos mais
/// usados; o Ctrl+⌘+Espaço do macOS continua disponível para a busca completa).
enum EmojiCatalog {
    static let groups: [(String, [String])] = [
        ("Rostos", ["😀", "😁", "😂", "🤣", "😊", "😍", "😘", "😎", "🤩", "🥳", "🤔", "😅", "😉", "🙂", "🙃", "😴", "😭", "😢", "😡", "🥺", "😳", "🤯", "😬", "🤗"]),
        ("Gestos", ["👍", "👎", "👏", "🙏", "🤝", "💪", "👌", "✌️", "🤞", "👋", "🙌", "🫶", "👇", "👉", "👆", "✍️", "🤙", "🫰"]),
        ("Corações", ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "💖", "💗", "💓", "💕", "💞", "❣️", "💔", "❤️‍🔥"]),
        ("Trabalho", ["✅", "❌", "⭐️", "🔥", "💡", "📈", "📉", "📊", "🎯", "🚀", "⚡️", "💰", "🏆", "📌", "📎", "🔑", "⏰", "📅", "✏️", "📝", "💬", "📣"]),
        ("Símbolos", ["✔️", "✖️", "➕", "➖", "❓", "❗️", "‼️", "⚠️", "♻️", "🔴", "🟢", "🟡", "🔵", "⚫️", "⚪️", "💯", "🆕", "🆗", "🔝"]),
        ("Setas", ["➡️", "⬅️", "⬆️", "⬇️", "↗️", "↘️", "↩️", "↪️", "🔁", "🔄", "🔼", "🔽", "▶️", "◀️"]),
    ]
}

struct PanelView: View {
    @ObservedObject var clipboard: ClipboardManager
    let onPick: (String) -> Void
    let onClear: () -> Void

    @State private var tab = 0
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Histórico").tag(0)
                Text("Emojis & Símbolos").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)

            Divider()

            if tab == 0 {
                historyTab
            } else {
                emojiTab
            }
        }
        .frame(width: 360, height: 440)
        .background(.ultraThinMaterial)
    }

    private var filteredHistory: [String] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return clipboard.history }
        return clipboard.history.filter { $0.lowercased().contains(q) }
    }

    private var historyTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 12))
                TextField("Buscar no histórico…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            if clipboard.history.isEmpty {
                emptyState("Nada copiado ainda", "Copie algo (⌘C) e aparecerá aqui.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filteredHistory.enumerated()), id: \.offset) { _, item in
                            Button { onPick(item) } label: {
                                HStack {
                                    Text(item.trimmingCharacters(in: .whitespacesAndNewlines))
                                        .lineLimit(2)
                                        .font(.system(size: 13))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "arrow.up.left.square")
                                        .foregroundStyle(.tertiary).font(.system(size: 11))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(HoverRowStyle())
                        }
                    }
                    .padding(6)
                }

                Divider()
                Button(action: onClear) {
                    Label("Limpar histórico", systemImage: "trash")
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(8)
            }
        }
    }

    private var emojiTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(EmojiCatalog.groups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.0.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8), spacing: 2) {
                            ForEach(group.1, id: \.self) { emoji in
                                Button { onPick(emoji) } label: {
                                    Text(emoji)
                                        .font(.system(size: 22))
                                        .frame(width: 38, height: 38)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(HoverCellStyle())
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private func emptyState(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard").font(.system(size: 28)).foregroundStyle(.tertiary)
            Text(title).font(.system(size: 13, weight: .medium))
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HoverRowStyle: ButtonStyle {
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.primary.opacity(0.08) : .clear))
            .onHover { hover = $0 }
    }
}

private struct HoverCellStyle: ButtonStyle {
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Color.primary.opacity(0.12) : .clear))
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .onHover { hover = $0 }
    }
}
