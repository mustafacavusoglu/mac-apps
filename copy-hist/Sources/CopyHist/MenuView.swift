import SwiftUI

/// Üst çubuk paneli: tek kaydırılabilir liste, aynı anda 10 satır görünür (toplam en fazla 50).
/// Arka plan MenuBarExtra'nın kendi saydam (vibrancy) malzemesi; burada ayrı renk verilmez.
struct MenuView: View {
    @ObservedObject var store: Store
    let watcher: Watcher

    var body: some View {
        VStack(spacing: 4) {
            if store.clips.isEmpty {
                Text("Kopyaladıkların burada görünecek")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).frame(height: Config.rowHeight * 3)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.clips) { clip in
                            Row(clip: clip,
                                onCopy: { watcher.copy(clip); NSApp.keyWindow?.close() },
                                onDelete: { store.remove(clip) })
                        }
                    }
                }
                .scrollIndicators(.automatic)
                .frame(height: min(CGFloat(store.clips.count), CGFloat(Config.visibleCount)) * Config.rowHeight)
            }
            HStack {
                Text("\(store.clips.count)").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button { store.clear() } label: { Image(systemName: "trash") }
                    .disabled(store.clips.isEmpty)
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .padding(.horizontal, 10).padding(.bottom, 2)
        }
        .padding(6)
        .frame(width: 340)
    }
}

struct Row: View {
    let clip: Clip
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 6) {
            Text(clip.preview).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            if hover {
                Button(action: onDelete) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            Image(systemName: "doc.on.doc").font(.caption)
                .foregroundStyle(hover ? .secondary : .quaternary)  // durgunken soluk, üzerine gelince belirgin
        }
        .padding(.horizontal, 10)
        .frame(height: Config.rowHeight)
        .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.primary.opacity(0.1) : .clear))
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
        .onHover { hover = $0 }
    }
}
