import AppKit
import SwiftUI

// MARK: - Ortak görünümler

/// Ana pencerenin altında yüzen kutu: işlem sürerken ilerleme, bitince sonuç (durum: Delete.swift).
struct ActivityHUD: View {
    @ObservedObject private var a = Activity.shared

    var body: some View {
        ZStack {
            if let title = a.title {
                HStack(spacing: 12) {
                    if a.total > 1 {
                        ProgressView(value: Double(a.done), total: Double(max(a.total, 1))).progressViewStyle(.circular).controlSize(.small)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                    Text(title).font(.headline)
                    if a.total > 1 {
                        Text("\(a.done) / \(a.total)").monospacedDigit().foregroundStyle(.secondary)
                            .contentTransition(.numericText(value: Double(a.done)))
                    }
                }
                .hud()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let t = a.toast {
                ToastView(t: t, close: a.close)
                    .id(t.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: a.title)
        .animation(.spring(duration: 0.4), value: a.toast?.id)
        .animation(.snappy, value: a.done)
        .padding(.bottom, 76)
    }
}

private struct ToastView: View {
    let t: Toast
    let close: () -> Void
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: t.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(t.ok ? Color.green : Color.orange)
                .symbolEffect(.bounce, value: bounce)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title).font(.headline)
                if let d = t.detail { Text(d).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            if let undo = t.undo {
                Button("Geri al") { Task { await undo() } }
            }
            Button(action: close) { Image(systemName: "xmark").font(.caption.bold()) }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Kapat")
        }
        .hud()
        .onAppear { bounce.toggle() }
    }
}

extension View {
    func hud() -> some View {
        padding(.horizontal, 16).padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            .frame(maxWidth: 560)
    }

    /// İşlemdeki satırı soluklaştırır.
    func pending(_ url: URL) -> some View { modifier(PendingRow(url: url)) }
}

private struct PendingRow: ViewModifier {
    @ObservedObject private var w = Working.shared
    let url: URL
    func body(content: Content) -> some View {
        // Klasörü işleniyorsa içindeki satırlar da soluklaşır (Sistem Çöpü'nde açılmış klasörler).
        content.opacity(w.pending.contains(url) || w.pending.contains { url.path.hasPrefix($0.path + "/") } ? 0.35 : 1)
    }
}

/// Çok öğeli klasörler sayfa sayfa gösterilir (binlerce satırı birden çizmek arayüzü dondurur).
let pageSize = 25

struct ShowMore: View {
    let remaining: Int
    let more: () -> Void
    var body: some View {
        Button(action: more) {
            Label("\(min(remaining, pageSize)) tane daha göster · \(remaining.formatted()) kaldı", systemImage: "chevron.down.circle")
        }
        .buttonStyle(.link)
        .padding(.vertical, 2)
    }
}

/// Bütün sekmelerde aynı "Seçili" göstergesi (sayı yumuşak değişir).
struct SelectedSize: View {
    let bytes: Int64
    var body: some View {
        Text("Seçili: \(fmt(bytes))").monospacedDigit()
            .contentTransition(.numericText(value: Double(bytes)))
            .animation(.snappy, value: bytes)
    }
}

/// Satır sonundaki tarih + boyut sütunları.
struct DateSize: View {
    let date: Date?, size: Int64
    var body: some View {
        Text(dateText(date)).foregroundStyle(.secondary).frame(width: 110, alignment: .trailing)
        Text(fmt(size)).monospacedDigit().foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
    }
}

struct BulkButtons: View {
    let all: () -> Void, none: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Button("Tümünü seç", action: all)
            Button("Hiçbirini seçme", action: none)
        }
    }
}

struct SortPicker: View {
    @Binding var key: SortKey
    var body: some View {
        Picker("Sırala", selection: $key) { ForEach(SortKey.allCases, id: \.self) { Text($0.rawValue) } }
            .pickerStyle(.segmented).fixedSize()
    }
}
