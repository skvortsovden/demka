import SwiftUI
import UIKit
import VisionKit

struct CardHeightKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

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
    @State private var showFontSizePicker = false
    @State private var showFontSizeToast = false
    @State private var showClicker = false
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
                        vm.rebuild()
                        withAnimation(.easeInOut(duration: 0.32)) { vm.fitAll() }
                    }
                    .onChange(of: geo.size) { _, newSize in
                        let prevSize    = vm.viewportSize
                        let wasLandscape = prevSize.width > prevSize.height
                        vm.viewportSize = newSize
                        let isLandscape = newSize.width > newSize.height

                        if wasLandscape != isLandscape {
                            // Orientation flipped — full rebuild with new card dimensions.
                            withAnimation(.easeInOut(duration: 0.32)) {
                                vm.rebuild(keepState: true)
                            }
                        } else if isLandscape && abs(newSize.height - prevSize.height) > 5 {
                            // Landscape canvas height shifted (toolbar appeared/disappeared).
                            // landscapeCardH must be recomputed from the new height so that
                            // focusCamera and zoomToReveal use a consistent node.h.
                            withAnimation(.easeInOut(duration: 0.32)) {
                                vm.rebuild(keepState: true)
                            }
                        } else if vm.isPresenting {
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
                clickerButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 20)
                    .padding(.bottom, 24)
                HStack(spacing: 12) {
                    viewModeButton
                    colorPickerButton
                    fontSizeButton
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 24)
                fitAllButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 20)
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

            // Font size toast
            if showFontSizeToast {
                Text("Font: \(vm.fontSize.label)")
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
        .overlay {
            if showClicker {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { showClicker = false }
                ClickerSheet(onDismiss: { showClicker = false })
                    .environmentObject(vm)
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showClicker)
        .onChange(of: vm.clickerConnected) { _, connected in
            if connected { showClicker = false }
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

            ForEach(vm.nodes) { node in
                positionedCard(for: node)
            }
        }
        .onPreferenceChange(CardHeightKey.self) { heights in
            vm.applyMeasuredHeights(heights)
        }
        .scaleEffect(vm.camScale, anchor: .topLeading)
        .offset(vm.camOffset)
    }

    // Landscape: fixed card height → offset by top-left is exact.
    // Portrait: variable card height → .position() guarantees the card's
    //           centre is always at (node.x + w/2, node.y + h/2) in canvas
    //           space, which is exactly what focusCamera targets.
    @ViewBuilder
    private func positionedCard(for node: Node) -> some View {
        if vm.viewportSize.width > vm.viewportSize.height {
            CardView(node: node)
                .environmentObject(vm)
                .offset(x: node.x, y: node.y)
        } else {
            CardView(node: node)
                .environmentObject(vm)
                .position(x: node.x + node.w / 2,
                          y: node.y + node.h / 2)
        }
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

    // MARK: - Font size button (floating)
    private var fontSizeButton: some View {
        Button {
            showFontSizePicker = true
        } label: {
            ZStack {
                Circle()
                    .fill(vm.theme.surface)
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
                Circle()
                    .stroke(vm.theme.line, lineWidth: 1)
                Image(systemName: "textformat.size")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(vm.theme.ink)
            }
            .frame(width: 44, height: 44)
        }
        .confirmationDialog("Font size", isPresented: $showFontSizePicker) {
            ForEach(FontSize.allCases) { size in
                Button(size.label) {
                    vm.fontSize = size
                    withAnimation(.spring(response: 0.25)) {
                        showFontSizeToast = true
                        showRevealToast = false
                        showZoomToast = false
                        showCardsToast = false
                        showTimerToast = false
                    }
                    toastTask?.cancel()
                    toastTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.5))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.25)) { showFontSizeToast = false }
                    }
                }
            }
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

    // MARK: - Clicker button
    private var clickerButton: some View {
        Button {
            if vm.clickerRemoteSessionActive {
                vm.isClickerMode = true
            } else if vm.clickerSessionId != nil {
                showClicker = true
            } else {
                vm.startClicker()
                showClicker = true
            }
        } label: {
            ZStack {
                let isConnected = vm.clickerConnected || vm.clickerRemoteConnected
                Circle()
                    .fill(isConnected
                          ? Color(red: 0.35, green: 0.62, blue: 0.44)
                          : vm.theme.surface)
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
                Circle()
                    .stroke(vm.theme.line, lineWidth: 1)
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isConnected ? .white : vm.theme.ink)
            }
            .frame(width: 44, height: 44)
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

            // ── Right: Present ───────────────────────────────
            HStack(spacing: 12) {
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

    // MARK: - Presentation overlay (xmark only — gestures handled by panGesture)
    private var presentationGestureLayer: some View {
        Color.clear
            .ignoresSafeArea()
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
                guard !vm.isPresenting else { return }
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
                let dx = value.translation.width
                let dy = value.translation.height
                let dist = hypot(dx, dy)

                if vm.isPresenting {
                    if dist < 12 {
                        // Tap: left half → back, right half → forward
                        if value.startLocation.x < vm.viewportSize.width / 2 {
                            vm.goBack()
                        } else {
                            vm.advance()
                        }
                    } else if abs(dy) > abs(dx) && abs(dy) > 60 {
                        // Vertical swipe → exit
                        withAnimation(.easeInOut(duration: 0.32)) {
                            vm.isPresenting = false
                            vm.fitAll()
                        }
                    } else {
                        let predDist = hypot(value.predictedEndTranslation.width,
                                            value.predictedEndTranslation.height)
                        let isFastSwipe = dist > 0 && predDist / dist > 2.5
                        if isFastSwipe && dx < -40 {
                            vm.jumpForward()
                        } else if isFastSwipe && dx > 40 {
                            vm.jumpBack()
                        }
                        // slow drag during presentation → ignore
                    }
                } else {
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
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
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
                noteRow("Do not share sensitive or confidential data.")
            }
            .padding(.bottom, 20)

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
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(vm.theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
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

// MARK: - Clicker sheet

struct ClickerSheet: View {
    @EnvironmentObject var vm: DeckViewModel
    var onDismiss: () -> Void
    @State private var showScanner = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Clicker")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(vm.theme.ink)
                .padding(.bottom, 4)

            Text("Scan with iPhone or iPad camera")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(vm.theme.mute)
                .padding(.bottom, 16)

            if let id = vm.clickerSessionId {
                let url = "demka://clicker/\(id)"
                if let img = qrImage(for: url) {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .background(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                Text(id)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(vm.theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 12)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(vm.clickerConnected ? Color(red: 0.35, green: 0.62, blue: 0.44) : vm.theme.mute)
                    .frame(width: 6, height: 6)
                if vm.clickerConnected, let name = vm.clickerPeerName {
                    Text("Connected — \(name)")
                        .font(.system(size: 13))
                        .foregroundColor(vm.theme.mute)
                } else {
                    Text("Waiting for clicker…")
                        .font(.system(size: 13))
                        .foregroundColor(vm.theme.mute)
                }
            }
            .padding(.bottom, 20)

            HStack {
                if vm.clickerConnected {
                    Button("Disconnect") {
                        vm.stopClicker()
                        onDismiss()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(vm.theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(vm.theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(vm.theme.ink, lineWidth: 1))
                    .cornerRadius(4)
                    .padding(.trailing, 8)
                }

                Button {
                    showScanner = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 13))
                        Text("Scan")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundColor(vm.theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(vm.theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(vm.theme.ink, lineWidth: 1))
                .cornerRadius(4)

                Spacer()

                Button("Close") { onDismiss() }
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
        .frame(maxWidth: 320)
        .background(vm.theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(vm.theme.ink, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
        .sheet(isPresented: $showScanner) {
            QRScannerView(
                onScan: { url in
                    showScanner = false
                    onDismiss()
                    vm.handleIncomingURL(URL(string: url) ?? URL(string: "demka://")!)
                },
                onDismiss: { showScanner = false }
            )
            .ignoresSafeArea()
        }
    }

    private func qrImage(for string: String) -> UIImage? {
        guard let data = string.data(using: .ascii),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ci = filter.outputImage else { return nil }
        let scale = 150 / ci.extent.width
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Clicker remote view (shown when this device is acting as the clicker)

struct ClickerRemoteView: View {
    @EnvironmentObject var vm: DeckViewModel

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Toolbar ───────────────────────────────────
                    toolbar

                    // ── Connection status line ────────────────────
                    statusLine

                    // ── Timer + counter row ───────────────────────
                    if vm.clickerRemoteConnected {
                        timerRow
                    }

                    // ── Content area (notes) + nav buttons ────────
                    if isLandscape {
                        HStack(alignment: .bottom, spacing: 0) {
                            VStack { Spacer(); navButton(symbol: "chevron.left", size: 72, iconSize: 26) { vm.sendClickerCommand("prev") }.padding(.bottom, 12) }
                            notesArea
                            VStack { Spacer(); navButton(symbol: "chevron.right", size: 72, iconSize: 26) { vm.sendClickerCommand("next") }.padding(.bottom, 12) }
                        }
                    } else {
                        notesArea
                        HStack(spacing: 40) {
                            navButton(symbol: "chevron.left",  size: 120, iconSize: 44) { vm.sendClickerCommand("prev") }
                            navButton(symbol: "chevron.right", size: 120, iconSize: 44) { vm.sendClickerCommand("next") }
                        }
                        .padding(.bottom, 48)
                    }
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            Button { vm.hideClickerMode() } label: {
                HStack(spacing: 4) {
                    Text("←")
                    Text("View")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.25), lineWidth: 1))
                .cornerRadius(4)
            }

            Spacer()

            HStack(spacing: 20) {
                remoteToggle("sparkles",              active: vm.clickerRemoteRevealEnabled, cmd: "toggleReveal")
                remoteToggle("plus.magnifyingglass",  active: vm.clickerRemoteZoomEnabled,   cmd: "toggleZoom")
                remoteToggle("rectangle.on.rectangle",active: vm.clickerRemoteCardsVisible,  cmd: "toggleCards")
                remoteToggle("timer",                 active: vm.clickerRemoteTimerEnabled,  cmd: "toggleTimer")
            }
            .disabled(!vm.clickerRemoteConnected)
            .opacity(vm.clickerRemoteConnected ? 1 : 0.3)

            Spacer()

            Button {
                vm.sendClickerCommand(vm.clickerRemoteIsPresenting ? "stopPresent" : "present")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: vm.clickerRemoteIsPresenting ? "stop.fill" : "play.fill")
                        .font(.system(size: 11))
                    Text(vm.clickerRemoteIsPresenting ? "Stop" : "Present")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(minWidth: 78)
                .foregroundColor(vm.clickerRemoteIsPresenting ? .white.opacity(0.55) : .black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(vm.clickerRemoteIsPresenting ? Color.white.opacity(0.12) : Color.white)
                .cornerRadius(4)
            }
            .disabled(!vm.clickerRemoteConnected)
            .opacity(vm.clickerRemoteConnected ? 1 : 0.3)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(vm.clickerRemoteConnected
                                 ? Color(red: 0.35, green: 0.62, blue: 0.44)
                                 : Color.gray.opacity(0.45))
            Text(vm.clickerRemoteConnected
                 ? "Connected to \(vm.clickerRemotePeerName ?? "")"
                 : vm.clickerRemoteDisconnected ? "Disconnected" : "Searching…")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var timerRow: some View {
        HStack(alignment: .top) {
            if vm.clickerRemoteTimerEnabled {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("total")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                        Text(vm.formatTime(vm.clickerRemoteTimerTotal))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    HStack(spacing: 4) {
                        Text("slide")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                        Text(vm.formatTime(vm.clickerRemoteTimerSlide))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
            }
            Spacer()
            if vm.clickerRemoteSlideTotal > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(spacing: 0) {
                        Text("\(vm.clickerRemoteSlideIndex)")
                        Text("/").padding(.horizontal, 2)
                        Text("\(vm.clickerRemoteSlideTotal)")
                    }
                    if vm.clickerRemoteBulletsTotal > 0 {
                        Text("\(vm.clickerRemoteBulletsShown)/\(vm.clickerRemoteBulletsTotal)")
                    }
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var notesArea: some View {
        Group {
            if vm.clickerRemoteConnected && vm.clickerRemoteSlideTotal > 0 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(vm.clickerRemoteSlideTitle)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !vm.clickerRemoteSlideNotes.isEmpty {
                            let notes = vm.clickerRemoteSlideNotes
                            let truncated = notes.count > 280
                                ? String(notes.prefix(280)) + "…"
                                : notes
                            Text(truncated)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.65))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            } else {
                Spacer()
            }
        }
    }

    private func remoteToggle(_ icon: String, active: Bool, cmd: String) -> some View {
        Button { vm.sendClickerCommand(cmd) } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(active ? .white : .white.opacity(0.25))
        }
    }

    private func navButton(symbol: String, size: CGFloat = 120, iconSize: CGFloat = 44, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(vm.clickerRemoteConnected
                          ? Color.white.opacity(0.12)
                          : Color.white.opacity(0.04))
                    .frame(width: size, height: size)
                Image(systemName: symbol)
                    .font(.system(size: iconSize, weight: .thin))
                    .foregroundColor(vm.clickerRemoteConnected ? .white : .white.opacity(0.3))
            }
        }
        .disabled(!vm.clickerRemoteConnected)
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

// MARK: - QR Scanner

struct QRScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !didScan else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let str = barcode.payloadStringValue {
                    didScan = true
                    DispatchQueue.main.async { self.onScan(str) }
                    return
                }
            }
        }
    }
}
