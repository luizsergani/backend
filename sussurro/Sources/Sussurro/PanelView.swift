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

private func isLink(_ s: String) -> Bool {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return t.hasPrefix("http://") || t.hasPrefix("https://") || t.hasPrefix("www.")
}

struct PanelView: View {
    @ObservedObject var clipboard: ClipboardManager
    let onPick: (String) -> Void
    let onClear: () -> Void

    @State private var tab = 0
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().opacity(0.6)
            Group {
                if tab == 0 { historyTab } else { emojiTab }
            }
        }
        .frame(width: 380, height: 460)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { searchFocused = true }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: tab == 0 ? "doc.on.clipboard" : "face.smiling")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(tab == 0 ? "Área de transferência" : "Emojis & Símbolos")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            HStack(spacing: 3) {
                Text("↵").font(.system(size: 10, weight: .semibold))
                Text("cola").font(.system(size: 10))
                Text("·").font(.system(size: 10)).foregroundStyle(.tertiary)
                Text("esc").font(.system(size: 10, weight: .semibold))
                Text("fecha").font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    private var tabBar: some View {
        Picker("", selection: $tab.animation(reduceMotion ? nil : .easeOut(duration: 0.15))) {
            Text("Histórico").tag(0)
            Text("Emojis").tag(1)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .onChange(of: tab) { _ in searchFocused = (tab == 0) }
    }

    // MARK: Histórico

    private var filteredHistory: [String] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return clipboard.history }
        return clipboard.history.filter { $0.lowercased().contains(q) }
    }

    private var historyTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary).font(.system(size: 12, weight: .medium))
                TextField("Buscar…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($searchFocused)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary).font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
            .padding(.horizontal, 14).padding(.vertical, 8)

            if clipboard.history.isEmpty {
                emptyState(icon: "doc.on.clipboard", title: "Nada copiado ainda",
                           subtitle: "Copie um texto (⌘C) e ele aparece aqui\nprontinho para colar de novo.")
            } else if filteredHistory.isEmpty {
                emptyState(icon: "magnifyingglass", title: "Nenhum resultado",
                           subtitle: "Nada no histórico corresponde a “\(search)”.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(Array(filteredHistory.enumerated()), id: \.offset) { _, item in
                            HistoryRow(text: item) { onPick(item) }
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                }
                footer
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.6)
            HStack {
                Text("\(clipboard.history.count) \(clipboard.history.count == 1 ? "item" : "itens")")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                Button(action: onClear) {
                    Label("Limpar", systemImage: "trash")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
        }
    }

    // MARK: Emojis

    private var emojiTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(EmojiCatalog.groups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(group.0.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8), spacing: 2) {
                            ForEach(group.1, id: \.self) { emoji in
                                EmojiCell(emoji: emoji) { onPick(emoji) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
    }

    // MARK: Empty state

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Linha do histórico

private struct HistoryRow: View {
    let text: String
    let action: () -> Void
    @State private var hover = false

    private var clean: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var link: Bool { isLink(text) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: link ? "link" : "text.alignleft")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(hover ? Color.accentColor : .secondary)
                    .frame(width: 16)
                Text(clean)
                    .lineLimit(2)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(link ? Color.accentColor : .primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "return")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(hover ? 1 : 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .frame(minHeight: 42)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hover ? Color.accentColor.opacity(0.12) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.08)) { hover = h }
        }
    }
}

// MARK: - Célula de emoji

private struct EmojiCell: View {
    let emoji: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 23))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(hover ? Color.accentColor.opacity(0.16) : .clear)
                )
                .scaleEffect(hover ? 1.12 : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.08)) { hover = h }
        }
        .help("Inserir \(emoji)")
    }
}
