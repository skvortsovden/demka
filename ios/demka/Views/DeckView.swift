import SwiftUI
import UIKit

struct DeckView: View {
    @EnvironmentObject var vm: DeckViewModel
    @State private var showHelp = false
    @State private var dragStartOffset: CGSize = .zero
    @State private var pinchStartScale: CGFloat = 1.0
    @State private var pinchStartOffset: CGSize = .zero
    @State private var isPinching = false
    @State private var showRevealToast = false
    @State private var showZoomToast = false
    @State private var showCardsToast = false
    @State private var showTimerToast = false
    @State private var toastTask: Task<Void, Never>? = nil
    @State private var showViewModePicker = false
    @State private var showThemePicker = false
    @State private var showShareConfirm = false
    @State private var shareURL: URL? = nil

    var body: some View {
        ZStack {
            vm.theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Toolbar — always on top, never covered ───
                if !vm.isPresenting {
                    toolbar
                }

                // ── Canvas fills remaining space ─────────────
                GeometryReader { geo in
                    ZStack {
                        canvasContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if vm.isPresenting {
                            presentationGestureLayer
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(panGesture)
                    .simultaneousGesture(pinchGesture)
                    .onAppear {
                        vm.viewportSize = geo.size
                        withAnimation(.easeInOut(duration: 0.32)) { vm.fitAll() }
                    }
                    .onChange(of: geo.size) { _, newSize in
                        vm.viewportSize = newSize
                        if vm.isPresenting {
                            vm.focusCamera(on: vm.activeIndex, animated: false)
                        } else {
                            withAnimation(.easeInOut(duration: 0.32)) { vm.fitAll() }
                        }
                    }
                    .onChange(of: vm.isPresenting) { _, presenting in
                        if !presenting {
                            withAnimation(.easeInOut(duration: 0.32)) { vm.fitAll() }
                        }
                    }
                }
            }

            // Floating buttons — outside the gesture layer so taps aren't swallowed
            if !vm.isPresenting {
                fitAllButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                VStack(spacing: 12) {
                    colorPickerButton
                    viewModeButton
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 20)
                .padding(.bottom, 24)
            }

            // Timer (top-left) + counter (top-right) on one line
            if vm.isPresenting {
                HStack(alignment: .top) {
                    if vm.timerEnabled {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text("total")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(vm.theme.ink2)
                                Text(vm.formatTime(vm.timerTotal))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(vm.theme.ink2)
                            }
                            HStack(spacing: 4) {
                                Text("slide")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(vm.theme.ink2)
                                Text(vm.formatTime(vm.timerSlide))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(vm.theme.ink2)
                            }
                        }
                    }
                    Spacer()
                    presentationCounter
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }

            // Timer toast
            if showTimerToast {
                Text(vm.timerEnabled ? "Timer enabled" : "Timer disabled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(vm.theme.bg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(vm.theme.ink.opacity(0.82))
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
            }

            // Zoom toast
            if showZoomToast {
                Text(vm.zoomEnabled ? "Zoom enabled" : "Zoom disabled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(vm.theme.bg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(vm.theme.ink.opacity(0.82))
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
            }

            // Cards toast
            if showCardsToast {
                Text(vm.cardsVisible ? "Cards visible" : "Cards hidden")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(vm.theme.bg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(vm.theme.ink.opacity(0.82))
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
            }

            // Reveal toast
            if showRevealToast {
                Text(vm.revealEnabled ? "Reveal enabled" : "Reveal disabled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(vm.theme.bg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(vm.theme.ink.opacity(0.82))
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
            }
        }
        .sheet(isPresented: $showHelp) {
            HelpView().environmentObject(vm)
        }
        .sheet(isPresented: $showShareConfirm) {
            ShareConfirmSheet(shareURL: $shareURL, onDismiss: { showShareConfirm = false })
                .environmentObject(vm)
        }
        .sheet(item: $shareURL) { url in
            ShareSheet(url: url)
        }
    }

    // MARK: - Canvas content
    private var canvasContent: some View {
        ZStack(alignment: .topLeading) {
            // Connectors drawn first (behind cards)
            ConnectorOverlay()
                .environmentObject(vm)
                .frame(
                    width: vm.root?.bounds.width ?? 1,
                    height: vm.root?.bounds.height ?? 1
                )

            // Cards
            ForEach(vm.nodes) { node in
                CardView(node: node)
                    .environmentObject(vm)
                    .position(
                        x: node.x + node.w / 2,
                        y: node.y + node.h / 2
                    )
            }
        }
        .scaleEffect(vm.camScale, anchor: .topLeading)
        .offset(vm.camOffset)
    }

    // MARK: - Presentation counter
    private var presentationCounter: some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack(spacing: 0) {
                Text("\(vm.activeIndex + 1)")
                Text("/").padding(.horizontal, 2)
                Text("\(vm.nodes.count)")
            }
            if vm.revealEnabled && !vm.nodes.isEmpty {
                let tot = vm.totalRevealSteps(for: vm.nodes[vm.activeIndex])
                if tot > 0 {
                    Text("\(min(vm.bulletsShown, tot))/\(tot)")
                }
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundColor(vm.theme.mute)
    }

    // MARK: - Timer toggle
    private var timerToggle: some View {
        Button {
            vm.timerEnabled.toggle()
            withAnimation(.spring(response: 0.25)) {
                showTimerToast = true
                showRevealToast = false
            }
            toastTask?.cancel()
            toastTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) { showTimerToast = false }
            }
        } label: {
            Image(systemName: "timer")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(vm.timerEnabled ? vm.theme.active : vm.theme.mute)
        }
    }

    // MARK: - Zoom toggle
    private var zoomToggle: some View {
        Button {
            vm.zoomEnabled.toggle()
            withAnimation(.spring(response: 0.25)) { showZoomToast = true; showRevealToast = false; showCardsToast = false; showTimerToast = false }
            toastTask?.cancel()
            toastTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) { showZoomToast = false }
            }
        } label: {
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(vm.zoomEnabled ? vm.theme.active : vm.theme.mute)
        }
    }

    // MARK: - Cards toggle
    private var cardsToggle: some View {
        Button {
            vm.cardsVisible.toggle()
            withAnimation(.spring(response: 0.25)) { showCardsToast = true; showRevealToast = false; showTimerToast = false }
            toastTask?.cancel()
            toastTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) { showCardsToast = false }
            }
        } label: {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(vm.cardsVisible ? vm.theme.active : vm.theme.mute)
        }
    }

    // MARK: - Reveal toggle
    private var revealToggle: some View {
        Button {
            vm.revealEnabled.toggle()
            withAnimation(.spring(response: 0.25)) { showRevealToast = true; showTimerToast = false }
            toastTask?.cancel()
            toastTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) { showRevealToast = false }
            }
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(vm.revealEnabled ? vm.theme.active : vm.theme.mute)
        }
    }

    // MARK: - Color picker button
    private var colorPickerButton: some View {
        Button {
            showThemePicker = true
        } label: {
            ZStack {
                Circle()
                    .fill(vm.theme.surface)
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
                Circle()
                    .stroke(vm.theme.line, lineWidth: 1)
                Circle()
                    .fill(vm.theme.active)
            }
            .frame(width: 44, height: 44)
        }
        .confirmationDialog("Theme", isPresented: $showThemePicker) {
            ForEach(Theme.all) { t in
                Button(t.name) { vm.theme = t }
            }
        }
    }

    // MARK: - View mode button
    private var viewModeButton: some View {
        Button {
            showViewModePicker = true
        } label: {
            ZStack {
                Circle()
                    .fill(vm.theme.surface)
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
                Circle()
                    .stroke(vm.theme.line, lineWidth: 1)
                ViewModeIcon(mode: vm.viewMode, color: vm.theme.ink)
                    .frame(width: 22, height: 15)
            }
            .frame(width: 44, height: 44)
        }
        .confirmationDialog("View", isPresented: $showViewModePicker) {
            ForEach(ViewMode.allCases) { mode in
                Button(mode.label) {
                    vm.viewMode = mode
                    vm.rebuild()
                }
            }
        }
    }

    // MARK: - Fit-all button
    private var fitAllButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.32)) { vm.fitAll() }
        } label: {
            ZStack {
                Circle()
                    .fill(vm.theme.surface)
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
                Circle()
                    .stroke(vm.theme.line, lineWidth: 1)
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(vm.theme.ink)
            }
            .frame(width: 44, height: 44)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Toolbar
    private var toolbar: some View {
        HStack(spacing: 0) {
            // ── Left: Edit ───────────────────────────────────
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { vm.showEditor = true }
            } label: {
                HStack(spacing: 4) {
                    Text("←")
                    Text("Edit")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(vm.theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(vm.theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(vm.theme.ink, lineWidth: 1))
                .cornerRadius(4)
            }

            Spacer()

            // ── Centre: Reveal · Zoom · Cards · Timer ────────
            HStack(spacing: 20) {
                revealToggle
                zoomToggle
                cardsToggle
                timerToggle
            }

            Spacer()

            // ── Right: Share + Present ───────────────────────
            HStack(spacing: 12) {
                Button {
                    showShareConfirm = true
                } label: {
                    if vm.isCreatingShare {
                        ProgressView()
                            .scaleEffect(0.75)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(vm.theme.ink)
                    }
                }
                .disabled(vm.isCreatingShare)

                Button {
                    vm.isPresenting = true
                    vm.activeIndex = 0
                    vm.bulletsShown = 0
                    vm.focusCamera(on: 0, animated: true)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text("Present")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(vm.theme.bg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(vm.theme.active)
                    .cornerRadius(4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(vm.theme.bg.opacity(0.95))
    }

    // MARK: - Presentation gesture layer
    private var presentationGestureLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        let dist = hypot(dx, dy)

                        if dist < 12 {
                            // Tap: left half → back, right half → forward
                            if value.startLocation.x < vm.viewportSize.width / 2 {
                                vm.goBack()
                            } else {
                                vm.advance()
                            }
                        } else if abs(dy) > abs(dx) && abs(dy) > 60 {
                            // Swipe up or down → exit
                            withAnimation(.easeInOut(duration: 0.32)) {
                                vm.isPresenting = false
                                vm.fitAll()
                            }
                        } else if dx < -40 {
                            // Swipe left → next card
                            vm.jumpForward()
                        } else if dx > 40 {
                            // Swipe right → prev card
                            vm.jumpBack()
                        }
                    }
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.32)) {
                        vm.isPresenting = false
                        vm.fitAll()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(vm.theme.mute)
                        .padding(14)
                }
                .padding(.top, 50)
                .padding(.trailing, 8)
            }
    }

    // MARK: - Gestures
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if vm.isPresenting { return }
                // Sync start offset at the beginning of each gesture so
                // programmatic camera moves (focusCamera, fitAll) don't cause a jump.
                if value.translation == .zero {
                    dragStartOffset = vm.camOffset
                }
                vm.camOffset = CGSize(
                    width:  dragStartOffset.width  + value.translation.width,
                    height: dragStartOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                if vm.isPresenting { return }
                let target = CGSize(
                    width:  dragStartOffset.width  + value.predictedEndTranslation.width,
                    height: dragStartOffset.height + value.predictedEndTranslation.height
                )
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.82)) {
                    vm.camOffset = target
                }
                dragStartOffset = target
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if vm.isPresenting { return }
                // Capture start state on first event of each gesture
                if !isPinching {
                    isPinching = true
                    pinchStartScale = vm.camScale
                    pinchStartOffset = vm.camOffset
                }
                let newScale = max(0.15, min(4.0, pinchStartScale * value.magnification))
                // Adjust offset so the point under the pinch center stays fixed
                let p = value.startLocation
                vm.camOffset = CGSize(
                    width:  p.x - (p.x - pinchStartOffset.width)  * newScale / pinchStartScale,
                    height: p.y - (p.y - pinchStartOffset.height) * newScale / pinchStartScale
                )
                vm.camScale = newScale
            }
            .onEnded { _ in
                if vm.isPresenting { return }
                isPinching = false
                pinchStartScale = vm.camScale
                pinchStartOffset = vm.camOffset
            }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ShareConfirmSheet: View {
    @EnvironmentObject var vm: DeckViewModel
    @Binding var shareURL: URL?
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Share demka")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(vm.theme.ink)
                .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 8) {
                noteRow("Your demka will be saved to the cloud.")
                noteRow("Anyone with the link can view it — no account needed.")
                noteRow("Link is stored for 1 month.")
            }

            Spacer()

            HStack(spacing: 10) {
                Button("Cancel") {
                    onDismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(vm.theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(vm.theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(vm.theme.line, lineWidth: 1))
                .cornerRadius(6)

                Spacer()

                Button {
                    onDismiss()
                    Task {
                        if let url = await vm.createShare() {
                            shareURL = url
                        }
                    }
                } label: {
                    if vm.isCreatingShare {
                        ProgressView()
                            .tint(vm.theme.bg)
                            .frame(width: 80)
                    } else {
                        Text("Create link")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(vm.theme.bg)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(vm.theme.active)
                .cornerRadius(6)
                .disabled(vm.isCreatingShare)
            }
            .padding(.bottom, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(vm.theme.bg.ignoresSafeArea())
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    private func noteRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(vm.theme.ink)
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(vm.theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - View mode icon

struct ViewModeIcon: View {
    let mode: ViewMode
    let color: Color
    var lineWidth: CGFloat = 1.5

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 20
            let sy = size.height / 14

            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x*sx, y: y*sy) }
            func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
                Path(CGRect(x: x*sx, y: y*sy, width: w*sx, height: h*sy))
            }
            func ln(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
                Path { p in p.move(to: pt(x1, y1)); p.addLine(to: pt(x2, y2)) }
            }

            let s = GraphicsContext.Shading.color(color)

            switch mode {
            case .timeline:
                ctx.stroke(box(1, 5.5, 4, 3),  with: s, lineWidth: lineWidth)
                ctx.stroke(ln(5, 7, 8, 7),      with: s, lineWidth: lineWidth)
                ctx.stroke(box(8, 5.5, 4, 3),   with: s, lineWidth: lineWidth)
                ctx.stroke(ln(12, 7, 15, 7),     with: s, lineWidth: lineWidth)
                ctx.stroke(box(15, 5.5, 4, 3),  with: s, lineWidth: lineWidth)

            case .map:
                ctx.stroke(box(8, 5.5, 4, 3),   with: s, lineWidth: lineWidth)
                ctx.stroke(box(1, 1, 4, 3),     with: s, lineWidth: lineWidth)
                ctx.stroke(box(1, 10, 4, 3),    with: s, lineWidth: lineWidth)
                ctx.stroke(box(15, 1, 4, 3),    with: s, lineWidth: lineWidth)
                ctx.stroke(box(15, 10, 4, 3),   with: s, lineWidth: lineWidth)
                ctx.stroke(ln(8, 6.5, 5, 2.5),  with: s, lineWidth: lineWidth)
                ctx.stroke(ln(8, 7.5, 5, 11.5), with: s, lineWidth: lineWidth)
                ctx.stroke(ln(12, 6.5, 15, 2.5), with: s, lineWidth: lineWidth)
                ctx.stroke(ln(12, 7.5, 15, 11.5),with: s, lineWidth: lineWidth)

            case .logic:
                ctx.stroke(box(1, 5.5, 4, 3),   with: s, lineWidth: lineWidth)
                ctx.stroke(box(13, 2, 4, 3),    with: s, lineWidth: lineWidth)
                ctx.stroke(box(13, 9, 4, 3),    with: s, lineWidth: lineWidth)
                ctx.stroke(ln(5, 7, 9, 7),       with: s, lineWidth: lineWidth)
                ctx.stroke(ln(9, 3.5, 9, 10.5),  with: s, lineWidth: lineWidth)
                ctx.stroke(ln(9, 3.5, 13, 3.5),  with: s, lineWidth: lineWidth)
                ctx.stroke(ln(9, 10.5, 13, 10.5),with: s, lineWidth: lineWidth)
            }
        }
    }
}
