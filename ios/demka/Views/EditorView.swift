import SwiftUI
import UIKit

// MARK: - Markdown text editor

private struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    var inkColor: UIColor
    var bgColor: UIColor
    var refreshTint: UIColor = .systemGray
    var onSetup: ((UITextView) -> Void)? = nil
    var onRefresh: (() async -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
            weight: .regular
        )
        tv.textColor = inkColor
        tv.backgroundColor = bgColor
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.smartQuotesType = .no
        tv.smartDashesType = .no
        tv.alwaysBounceVertical = true

        let rc = UIRefreshControl()
        rc.tintColor = refreshTint
        rc.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        tv.refreshControl = rc

        onSetup?(tv)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        if tv.text != text { tv.text = text }
        tv.textColor = inkColor
        tv.backgroundColor = bgColor
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextEditor
        init(_ parent: MarkdownTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }

        @objc func handleRefresh(_ control: UIRefreshControl) {
            Task { @MainActor in
                await parent.onRefresh?()
                control.endRefreshing()
            }
        }
    }
}

// MARK: - Editor screen

private final class TextViewStore: ObservableObject {
    var textView: UITextView?
}

struct EditorView: View {
    @EnvironmentObject var vm: DeckViewModel
    @StateObject private var store = TextViewStore()
    @State private var keyboardVisible = false
    @State private var showShareConfirm = false
    @State private var showAbout = false
    @State private var shareURL: URL? = nil
    @State private var exportURL: URL? = nil

    var body: some View {
        ZStack {
            vm.theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top toolbar ──────────────────────────────
                HStack {
                    Button { showAbout = true } label: {
                        Text("demka")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(vm.theme.ink)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Menu {
                            Button {
                                showShareConfirm = true
                            } label: {
                                Label("Share link", systemImage: "link")
                            }
                            Button {
                                Task {
                                    if let url = await vm.exportPDF() {
                                        exportURL = url
                                    }
                                }
                            } label: {
                                Label("Export PDF", systemImage: "doc.richtext")
                            }
                            Button {
                                if let url = vm.exportMarkdown() {
                                    exportURL = url
                                }
                            } label: {
                                Label("Export Markdown", systemImage: "doc.text")
                            }
                        } label: {
                            if vm.isCreatingShare || vm.isExportingPDF {
                                ProgressView()
                                    .scaleEffect(0.75)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(vm.theme.ink)
                            }
                        }
                        .disabled(vm.isCreatingShare || vm.isExportingPDF)

                        Button {
                            vm.rebuild()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                vm.showEditor = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("View")
                                Text("→")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(vm.theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(vm.theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(vm.theme.ink, lineWidth: 1))
                            .cornerRadius(4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider().background(vm.theme.line)

                // ── Editor ───────────────────────────────────
                MarkdownTextEditor(
                    text: $vm.markdown,
                    inkColor: UIColor(vm.theme.ink),
                    bgColor:  UIColor(vm.theme.bg),
                    refreshTint: UIColor(vm.theme.ink2),
                    onSetup:  { tv in store.textView = tv },
                    onRefresh: { await vm.refreshShare() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if keyboardVisible { keyboardToolbar }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .overlay {
            if showShareConfirm {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { showShareConfirm = false }
                ShareConfirmSheet(shareURL: $shareURL, onDismiss: { showShareConfirm = false })
                    .environmentObject(vm)
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            if showAbout {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { showAbout = false }
                AboutSheet(onDismiss: { showAbout = false })
                    .environmentObject(vm)
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showShareConfirm)
        .animation(.easeOut(duration: 0.2), value: showAbout)
        .sheet(item: $shareURL) { url in
            ShareSheet(url: url)
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(url: url)
        }
    }

    // MARK: - Keyboard toolbar

    private var keyboardToolbar: some View {
        HStack(spacing: 0) {
            toolbarIcon("chevron.left")  { store.textView?.undoManager?.undo() }
            toolbarDivider
            toolbarIcon("chevron.right") { store.textView?.undoManager?.redo() }
            toolbarDivider

            Menu {
                Button("H1 — Heading 1") { insertHeader("# ") }
                Button("H2 — Heading 2") { insertHeader("## ") }
                Button("H3 — Heading 3") { insertHeader("### ") }
            } label: {
                Text("H")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(vm.theme.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            toolbarDivider
            toolbarTitle("B") { store.textView?.insertText("**text**") }
            toolbarDivider
            toolbarIcon("keyboard.chevron.compact.down") { store.textView?.resignFirstResponder() }
        }
        .frame(height: 44)
        .background(vm.theme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(vm.theme.line).frame(height: 0.5)
        }
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(vm.theme.line)
            .frame(width: 0.5)
            .padding(.vertical, 10)
    }

    private func toolbarIcon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(vm.theme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func toolbarTitle(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(vm.theme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func insertHeader(_ prefix: String) {
        guard let tv = store.textView else { return }
        let ns = tv.text as NSString
        let lineRange = ns.lineRange(for: NSRange(location: tv.selectedRange.location, length: 0))
        tv.selectedRange = NSRange(location: lineRange.location, length: 0)
        tv.insertText(prefix)
    }
}

// MARK: - About sheet

struct AboutSheet: View {
    @EnvironmentObject var vm: DeckViewModel
    var onDismiss: () -> Void

    private let features: [(String, String)] = [
        ("Markdown",  "headings become slides, bullets reveal one by one"),
        ("Reveal",    "animate bullets one by one during presentation"),
        ("Cards",     "toggle card borders on/off"),
        ("Themes",    "Stone, Midnight, Amber"),
        ("Font size", "Small, Medium, Large"),
        ("Timer",     "total and per-slide time in presentation mode"),
        ("Export",    "PDF, Markdown, or share link (cloud)"),
        ("Auto-save", "content persists locally"),
    ]

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("demka")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(vm.theme.ink)
                .padding(.bottom, 14)

            Text("Features")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(vm.theme.mute)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(features, id: \.0) { key, desc in
                    (Text(key).fontWeight(.semibold).foregroundColor(vm.theme.ink)
                     + Text(" — ").foregroundColor(vm.theme.ink2)
                     + Text(desc).foregroundColor(vm.theme.ink2))
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 16)

            VStack(alignment: .center, spacing: 3) {
                Text("version \(version)")
                Link("demka.in.ua", destination: URL(string: "https://demka.in.ua")!)
                    .foregroundColor(vm.theme.active)
                Text("created by Denys Skvortsov")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(vm.theme.mute)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)

            HStack {
                Spacer()
                Button("Got it") { onDismiss() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(vm.theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(vm.theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(vm.theme.ink, lineWidth: 1))
                    .cornerRadius(4)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(vm.theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(vm.theme.ink, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
    }
}
