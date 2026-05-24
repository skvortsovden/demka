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

    var body: some View {
        ZStack {
            vm.theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top toolbar ──────────────────────────────
                HStack {
                    Text("demka")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(vm.theme.ink)

                    Spacer()

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
