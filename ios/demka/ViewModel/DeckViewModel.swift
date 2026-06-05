import SwiftUI
import UIKit
import Combine

private let kMarkdown  = "demka.md"
private let kViewMode  = "demka.viewMode"
private let kTheme     = "demka.theme"
private let kReveal    = "demka.reveal"
private let kTimer     = "demka.timer"
private let kCards     = "demka.cards"
private let kZoom      = "demka.zoom"
private let kFontSize  = "demka.fontSize"

@MainActor
final class DeckViewModel: ObservableObject {

    // MARK: - Published state
    @Published var markdown: String {
        didSet { UserDefaults.standard.set(markdown, forKey: kMarkdown) }
    }
    @Published var viewMode: ViewMode {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: kViewMode) }
    }
    @Published var theme: Theme {
        didSet { UserDefaults.standard.set(theme.name, forKey: kTheme) }
    }
    @Published var showEditor: Bool = true
    @Published var nodes: [Node] = []
    @Published var activeIndex: Int = 0
    @Published var bulletsShown: Int = 0
    @Published var zoomRevealActive: Bool = false  // dims previous bullets, highlights current
    @Published var isPresenting: Bool = false {
        didSet {
            if isPresenting { timerStart() } else { timerStop() }
            if clickerConnected { sendSettingsToClicker() }
        }
    }
    @Published var visitedIds: Set<String> = []
    @Published var revealEnabled: Bool {
        didSet {
            UserDefaults.standard.set(revealEnabled, forKey: kReveal)
            if clickerConnected { sendSettingsToClicker() }
        }
    }
    @Published var cardsVisible: Bool {
        didSet {
            UserDefaults.standard.set(cardsVisible, forKey: kCards)
            if clickerConnected { sendSettingsToClicker() }
        }
    }
    @Published var zoomEnabled: Bool {
        didSet {
            UserDefaults.standard.set(zoomEnabled, forKey: kZoom)
            if clickerConnected { sendSettingsToClicker() }
        }
    }
    @Published var timerEnabled: Bool {
        didSet {
            UserDefaults.standard.set(timerEnabled, forKey: kTimer)
            if isPresenting { timerEnabled ? timerStart() : timerStop() }
            if clickerConnected { sendTimerToClicker() }
        }
    }
    @Published var fontSize: FontSize {
        didSet {
            UserDefaults.standard.set(fontSize.rawValue, forKey: kFontSize)
            LayoutEngine.fontSize = fontSize
            rebuild()
        }
    }
    @Published var timerTotal: Int = 0
    @Published var timerSlide: Int = 0
    private var timerTask: Task<Void, Never>?

    // MARK: - Camera
    @Published var camOffset: CGSize = .zero
    @Published var camScale: CGFloat = 1.0

    // MARK: - Internal
    private(set) var root: RootNode?
    var viewportSize: CGSize = CGSize(width: 390, height: 844)

    // MARK: - Init
    init() {
        let saved = UserDefaults.standard.string(forKey: kMarkdown) ?? ""
        self.markdown = saved.isEmpty ? DeckViewModel.defaultMarkdown : saved

        let modeRaw = UserDefaults.standard.string(forKey: kViewMode) ?? "timeline"
        self.viewMode = ViewMode(rawValue: modeRaw) ?? .timeline

        let themeName = UserDefaults.standard.string(forKey: kTheme) ?? "Stone"
        self.theme = Theme.all.first(where: { $0.name == themeName }) ?? .stone

        self.revealEnabled = UserDefaults.standard.object(forKey: kReveal) as? Bool ?? true
        self.cardsVisible  = UserDefaults.standard.object(forKey: kCards) as? Bool ?? true
        self.zoomEnabled   = UserDefaults.standard.object(forKey: kZoom)  as? Bool ?? false
        self.timerEnabled  = UserDefaults.standard.object(forKey: kTimer) as? Bool ?? false

        let fontSizeRaw = UserDefaults.standard.string(forKey: kFontSize) ?? "medium"
        self.fontSize = FontSize(rawValue: fontSizeRaw) ?? .medium
        LayoutEngine.fontSize = self.fontSize

        rebuild()
    }

    // MARK: - Rebuild
    func rebuild(keepState: Bool = false) {
        let savedActive  = activeIndex
        let savedBullets = bulletsShown
        let savedVisited = visitedIds

        let isLandscape = viewportSize.width > viewportSize.height
        LayoutEngine.landscapeCardH = isLandscape ? (viewportSize.height * 0.85).rounded() : 0
        LayoutEngine.cardW = max(220, viewportSize.width * 0.8)
        LayoutEngine.fontSize = fontSize

        let parsed = MarkdownParser.parse(markdown)
        if viewMode == .map || viewMode == .logic {
            LayoutEngine.promoteFirstAsRoot(parsed)
        }
        root = parsed
        switch viewMode {
        case .timeline: LayoutEngine.layoutTimeline(parsed)
        case .map:      LayoutEngine.layoutMap(parsed)
        case .logic:    LayoutEngine.layoutLogic(parsed)
        }
        let flat = parsed.flatten()
        nodes = flat

        if keepState {
            activeIndex  = min(savedActive, max(0, flat.count - 1))
            bulletsShown = savedBullets
            visitedIds   = savedVisited
            if isPresenting { focusCamera(on: activeIndex, animated: false) }
            else            { fitAll() }
        } else {
            if activeIndex >= flat.count { activeIndex = max(0, flat.count - 1) }
            bulletsShown = 0
            visitedIds   = []
            fitAll()
        }
    }

    // MARK: - Two-pass layout (measure → re-position)
    func applyMeasuredHeights(_ heights: [String: CGFloat]) {
        guard viewportSize.width <= viewportSize.height else { return } // fixed in landscape
        var changed = false
        for node in nodes {
            if let h = heights[node.id], h > 1, abs(h - node.h) > 1 {
                node.h = h
                changed = true
            }
        }
        guard changed else { return }
        withTransaction(Transaction(animation: nil)) { relayout() }
    }

    private func relayout() {
        guard let root = root else { return }
        switch viewMode {
        case .timeline: LayoutEngine.layoutTimeline(root, resetHeights: false)
        case .map:      LayoutEngine.layoutMap(root, resetHeights: false)
        case .logic:    LayoutEngine.layoutLogic(root, resetHeights: false)
        }
        nodes = root.flatten()
        if isPresenting { focusCamera(on: activeIndex, animated: false) }
        else            { fitAll() }
    }

    // MARK: - Timer
    func timerStart() {
        guard timerEnabled else { return }
        timerTotal = 0
        timerSlide = 0
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                timerTotal += 1
                timerSlide += 1
                if clickerConnected { sendTimerToClicker() }
            }
        }
    }

    func timerStop() {
        timerTask?.cancel()
        timerTask = nil
    }

    func timerResetSlide() {
        timerSlide = 0
    }

    func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    // MARK: - Presentation navigation
    func totalRevealSteps(for node: Node) -> Int {
        var c = node.lede.isEmpty ? 0 : 1
        c += min(node.bullets.count, LayoutEngine.maxBullets)
        return c
    }

    // highlight=true  → dim previous bullets, full-opacity on current (forward nav)
    // highlight=false → clear dimming but still pan to current bullet (back nav)
    func zoomToReveal(highlight: Bool = true) {
        guard zoomEnabled, revealEnabled, activeIndex < nodes.count else { return }
        let node = nodes[activeIndex]
        let vw = viewportSize.width, vh = viewportSize.height
        let isLandscape = vw > vh
        var base: CGFloat
        if isLandscape {
            let byHeight = (vh * 0.8) / node.h
            let byWidth  = (vw - 40) / node.w
            base = min(byHeight, byWidth)
        } else {
            let pad: CGFloat = 60
            base = min(vw / (node.w + pad * 2), vh / (node.h + pad * 2))
            base = min(base, 1.55); base = max(base, 0.5)
        }
        // Zoom in 1.3× then clamp so the card never overflows the viewport.
        // This works for both orientations: in landscape the cap kicks in and
        // limits how far we zoom (card already fills most of the screen).
        let zoomed = base * 1.3
        let capByH = (vh - 20) / node.h
        let capByW = (vw - 20) / node.w
        let s = max(0.3, min(zoomed, capByH, capByW))

        // Pan to the centre of the currently revealed element, mirroring the web version.
        let focusX = node.x + node.w / 2
        let focusY = revealedElementCanvasY(node: node, step: bulletsShown)

        zoomRevealActive = highlight

        withAnimation(.easeInOut(duration: 0.28)) {
            camScale = s
            camOffset = CGSize(width: vw / 2 - focusX * s,
                               height: vh / 2 - focusY * s)
        }
    }

    // Estimates the canvas Y of the centre of the element revealed at `step`.
    // Mirrors the padding/font constants used in computeCardHeight and CardView.
    private func revealedElementCanvasY(node: Node, step: Int) -> CGFloat {
        let availW = max(80, LayoutEngine.cardW - 32)
        let scale = LayoutEngine.fontSize.scale
        let (charW, lineH): (CGFloat, CGFloat)
        switch node.level {
        case 1:  (charW, lineH) = (13.0 * scale, 36 * scale)
        case 2:  (charW, lineH) = (10.0 * scale, 28 * scale)
        default: (charW, lineH) = ( 7.5 * scale, 22 * scale)
        }
        let charsPerLine = max(8, Int(availW / charW))
        let titleLines   = max(1, Int(ceil(Double(node.title.count) / Double(charsPerLine))))
        // Title section: 14 top + title + 10 bottom
        let titleSectionH: CGFloat = 14 + CGFloat(titleLines) * lineH + 10

        let ledeH:   CGFloat = 18 * scale
        let bulletH: CGFloat = 18 * scale
        let gap:     CGFloat = 6
        let hasLede = !node.lede.isEmpty

        let yInCard: CGFloat
        if hasLede && step == 1 {
            // Lede is the revealed element
            yInCard = titleSectionH + ledeH / 2
        } else {
            let bulletIdx = hasLede ? step - 2 : step - 1
            var y = titleSectionH
            if hasLede { y += ledeH + gap }
            y += CGFloat(max(0, bulletIdx)) * (bulletH + gap)
            y += bulletH / 2
            yInCard = y
        }
        return node.y + yInCard
    }

    func advance() {
        guard !nodes.isEmpty else { return }
        let cur = nodes[activeIndex]
        let tot = totalRevealSteps(for: cur)
        if revealEnabled && bulletsShown < tot {
            withAnimation(.easeOut(duration: 0.18)) { bulletsShown += 1 }
            zoomToReveal(highlight: true)
            return
        }
        if activeIndex < nodes.count - 1 {
            zoomRevealActive = false
            markVisited(activeIndex)
            withAnimation(.easeInOut(duration: 0.32)) {
                activeIndex += 1
                bulletsShown = 0
            }
            timerResetSlide()
            focusCamera(on: activeIndex, animated: true)
        }
    }

    func goBack() {
        guard !nodes.isEmpty else { return }
        if revealEnabled && bulletsShown > 0 {
            withAnimation(.easeOut(duration: 0.18)) { bulletsShown -= 1 }
            if bulletsShown == 0 {
                zoomRevealActive = false
                focusCamera(on: activeIndex, animated: true)
            } else {
                // Pan to the new current bullet but without dimming (mirrors web back())
                zoomToReveal(highlight: false)
            }
            return
        }
        if activeIndex > 0 {
            zoomRevealActive = false
            withAnimation(.easeInOut(duration: 0.32)) {
                activeIndex -= 1
                bulletsShown = totalRevealSteps(for: nodes[activeIndex])
            }
            timerResetSlide()
            focusCamera(on: activeIndex, animated: true)
        }
    }

    func jumpForward() {
        guard !nodes.isEmpty, activeIndex < nodes.count - 1 else { return }
        zoomRevealActive = false
        markVisited(activeIndex)
        withAnimation(.easeInOut(duration: 0.32)) {
            activeIndex += 1
            bulletsShown = 0
        }
        timerResetSlide()
        focusCamera(on: activeIndex, animated: true)
    }

    func jumpBack() {
        guard !nodes.isEmpty, activeIndex > 0 else { return }
        zoomRevealActive = false
        withAnimation(.easeInOut(duration: 0.32)) {
            activeIndex -= 1
            bulletsShown = 0
        }
        timerResetSlide()
        focusCamera(on: activeIndex, animated: true)
    }

    func activateNode(_ node: Node) {
        guard let idx = nodes.firstIndex(where: { $0.id == node.id }) else { return }
        zoomRevealActive = false
        if idx != activeIndex { markVisited(activeIndex) }
        withAnimation(.easeInOut(duration: 0.32)) {
            activeIndex = idx
            bulletsShown = 0
        }
        focusCamera(on: idx, animated: true)
    }

    // MARK: - Camera
    func fitAll() {
        guard let root = root else { return }
        let b = root.bounds
        guard b.width > 0, b.height > 0 else { return }
        let vw = viewportSize.width
        let vh = viewportSize.height
        let pad: CGFloat = 32
        let scaleX = (vw - pad * 2) / b.width
        let scaleY = (vh - pad * 2) / b.height
        let s = min(scaleX, scaleY, 1.5)
        camScale  = s
        camOffset = CGSize(width:  (vw - b.width  * s) / 2,
                           height: (vh - b.height * s) / 2)
    }

    func focusCamera(on idx: Int, animated: Bool) {
        guard idx < nodes.count else { return }
        let node = nodes[idx]
        let vw = viewportSize.width
        let vh = viewportSize.height
        let isLandscape = vw > vh
        // When the timer is visible, reserve space at the top so the card
        // doesn't slide behind the timer/counter overlay.
        let topInset: CGFloat = (isPresenting && timerEnabled) ? 52 : 0
        let effectiveVH = vh - topInset
        var s: CGFloat
        if isLandscape {
            // Target 80 % of effective height; clamp so card doesn't exceed width.
            let byHeight = (effectiveVH * 0.8) / node.h
            let byWidth  = (vw - 40) / node.w
            s = min(byHeight, byWidth)
        } else {
            let pad: CGFloat = 60
            s = min(vw / (node.w + pad * 2), effectiveVH / (node.h + pad * 2))
            s = min(s, 1.55)
        }
        s = max(s, 0.3)
        let tx = vw / 2 - (node.x + node.w / 2) * s
        let ty = topInset + effectiveVH / 2 - (node.y + node.h / 2) * s
        if animated {
            withAnimation(.easeInOut(duration: 0.32)) {
                camScale  = s
                camOffset = CGSize(width: tx, height: ty)
            }
        } else {
            camScale  = s
            camOffset = CGSize(width: tx, height: ty)
        }
    }

    // MARK: - Clicker (presenter side — advertises over Bluetooth/WiFi via MPC)
    @Published var clickerSessionId: String? = nil
    @Published var clickerConnected = false
    @Published var clickerPeerName: String? = nil
    private var clickerHostSession: ClickerSession?

    func startClicker() {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        let id = (0..<6).map { _ in String(chars.randomElement()!) }.joined()
        clickerSessionId = id
        clickerConnected = false
        clickerPeerName = nil

        let cs = ClickerSession()
        cs.onConnected   = { [weak self, weak cs] in
            self?.clickerConnected = true
            self?.clickerPeerName  = cs?.connectedPeerName
            self?.sendSlideInfoToClicker()
            self?.sendTimerToClicker()
            self?.sendSettingsToClicker()
        }
        cs.onDisconnected = { [weak self] in
            self?.clickerConnected = false
            self?.clickerPeerName  = nil
        }
        cs.onCommand = { [weak self] cmd in
            guard let self else { return }
            if cmd == "next" {
                self.advance()
                self.sendSlideInfoToClicker()
            } else if cmd == "prev" {
                self.goBack()
                self.sendSlideInfoToClicker()
            } else if cmd == "toggleTimer" {
                self.timerEnabled.toggle()
                self.sendTimerToClicker()
            } else if cmd == "toggleReveal" {
                self.revealEnabled.toggle()
            } else if cmd == "toggleZoom" {
                self.zoomEnabled.toggle()
            } else if cmd == "toggleCards" {
                self.cardsVisible.toggle()
            } else if cmd == "present" {
                self.isPresenting = true
                self.activeIndex  = 0
                self.bulletsShown = 0
                self.focusCamera(on: 0, animated: true)
            } else if cmd == "stopPresent" {
                self.isPresenting = false
            }
        }
        cs.startHosting(sessionId: id)
        clickerHostSession = cs
    }

    func stopClicker() {
        clickerHostSession?.stopAll()
        clickerHostSession = nil
        clickerSessionId  = nil
        clickerConnected  = false
        clickerPeerName   = nil
    }

    // MARK: - Clicker remote mode (this iPhone acts as the clicker)
    @Published var isClickerMode = false
    @Published var clickerRemoteSessionActive = false
    @Published var clickerRemoteConnected = false
    @Published var clickerRemoteDisconnected = false
    @Published var clickerRemotePeerName: String? = nil
    @Published var clickerRemoteSlideTitle: String = ""
    @Published var clickerRemoteSlideNotes: String = ""
    @Published var clickerRemoteSlideIndex: Int = 0
    @Published var clickerRemoteSlideTotal: Int = 0
    @Published var clickerRemoteBulletsShown: Int = 0
    @Published var clickerRemoteBulletsTotal: Int = 0
    @Published var clickerRemoteTimerEnabled: Bool = false
    @Published var clickerRemoteTimerTotal: Int = 0
    @Published var clickerRemoteTimerSlide: Int = 0
    @Published var clickerRemoteRevealEnabled: Bool = true
    @Published var clickerRemoteZoomEnabled: Bool = false
    @Published var clickerRemoteCardsVisible: Bool = true
    @Published var clickerRemoteIsPresenting: Bool = false
    private var clickerRemoteSession: ClickerSession?

    func hideClickerMode() {
        isClickerMode = false
        showEditor = false
    }

    func startClickerRemote(sessionId: String) {
        isClickerMode               = true
        clickerRemoteSessionActive  = true
        clickerRemoteConnected      = false
        clickerRemoteDisconnected   = false
        clickerRemotePeerName       = nil

        let cs = ClickerSession()
        cs.onConnected   = { [weak self, weak cs] in
            self?.clickerRemoteConnected = true
            self?.clickerRemotePeerName  = cs?.connectedPeerName
        }
        cs.onDisconnected = { [weak self] in
            self?.clickerRemoteConnected      = false
            self?.clickerRemotePeerName       = nil
            self?.clickerRemoteDisconnected   = true
            self?.clickerRemoteSessionActive  = false
        }
        cs.onCommand = { [weak self] msg in
            guard let self,
                  let data = msg.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            switch json["type"] as? String {
            case "slide":
                self.clickerRemoteSlideTitle   = json["title"]         as? String ?? ""
                self.clickerRemoteSlideNotes   = json["notes"]         as? String ?? ""
                self.clickerRemoteSlideIndex   = json["index"]         as? Int    ?? 0
                self.clickerRemoteSlideTotal   = json["total"]         as? Int    ?? 0
                self.clickerRemoteBulletsShown = json["bulletsShown"]  as? Int    ?? 0
                self.clickerRemoteBulletsTotal = json["bulletsTotal"]  as? Int    ?? 0
            case "timer":
                self.clickerRemoteTimerEnabled = json["enabled"]       as? Bool   ?? false
                self.clickerRemoteTimerTotal   = json["total"]         as? Int    ?? 0
                self.clickerRemoteTimerSlide   = json["slide"]         as? Int    ?? 0
            case "settings":
                self.clickerRemoteRevealEnabled = json["reveal"]       as? Bool   ?? true
                self.clickerRemoteZoomEnabled   = json["zoom"]         as? Bool   ?? false
                self.clickerRemoteCardsVisible  = json["cards"]        as? Bool   ?? true
                self.clickerRemoteIsPresenting  = json["presenting"]   as? Bool   ?? false
            default: break
            }
        }
        cs.startBrowsing(sessionId: sessionId)
        clickerRemoteSession = cs
    }

    func stopClickerRemote() {
        clickerRemoteSession?.stopAll()
        clickerRemoteSession        = nil
        isClickerMode               = false
        clickerRemoteSessionActive  = false
        clickerRemoteConnected      = false
        clickerRemotePeerName       = nil
        clickerRemoteSlideTitle     = ""
        clickerRemoteSlideNotes     = ""
        clickerRemoteSlideIndex     = 0
        clickerRemoteSlideTotal     = 0
        clickerRemoteBulletsShown   = 0
        clickerRemoteBulletsTotal   = 0
        clickerRemoteTimerEnabled   = false
        clickerRemoteTimerTotal     = 0
        clickerRemoteTimerSlide     = 0
        clickerRemoteRevealEnabled  = true
        clickerRemoteZoomEnabled    = false
        clickerRemoteCardsVisible   = true
        clickerRemoteIsPresenting   = false
    }

    func sendClickerCommand(_ cmd: String) {
        clickerRemoteSession?.send(cmd)
    }

    private func sendSlideInfoToClicker() {
        guard let cs = clickerHostSession, !nodes.isEmpty else { return }
        let node = nodes[activeIndex]
        let payload: [String: Any] = [
            "type":         "slide",
            "title":        node.title,
            "notes":        node.notes,
            "index":        activeIndex + 1,
            "total":        nodes.count,
            "bulletsShown": bulletsShown,
            "bulletsTotal": totalRevealSteps(for: node)
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let msg  = String(data: data, encoding: .utf8) else { return }
        cs.send(msg)
    }

    private func sendSettingsToClicker() {
        guard let cs = clickerHostSession else { return }
        let payload: [String: Any] = [
            "type":       "settings",
            "reveal":     revealEnabled,
            "zoom":       zoomEnabled,
            "cards":      cardsVisible,
            "presenting": isPresenting
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let msg  = String(data: data, encoding: .utf8) else { return }
        cs.send(msg)
    }

    private func sendTimerToClicker() {
        guard let cs = clickerHostSession else { return }
        let payload: [String: Any] = [
            "type":    "timer",
            "enabled": timerEnabled,
            "total":   timerTotal,
            "slide":   timerSlide
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let msg  = String(data: data, encoding: .utf8) else { return }
        cs.send(msg)
    }

    private var firestoreBase: String { "https://firestore.googleapis.com/v1/projects/demka-944f1/databases/(default)/documents" }
    private var firestoreKey:  String { "AIzaSyBMQMTFQwWaqDcId-knFXw0Fh5VQCqQo3k" }

    // MARK: - Share loading / creating
    @Published var isLoadingShare = false
    @Published var isCreatingShare = false
    @Published var isExportingPDF = false
    @Published var shareError: String? = nil

    func handleIncomingURL(_ url: URL) {
        // Clicker remote: demka://clicker/<sessionId>
        if url.scheme == "demka", url.host == "clicker" {
            let id = url.pathComponents.dropFirst().first ?? ""
            if !id.isEmpty { startClickerRemote(sessionId: id) }
            return
        }
        // Share link
        var shareId: String? = nil
        if let fragment = url.fragment, fragment.hasPrefix("share:") {
            shareId = String(fragment.dropFirst(6))
        } else if url.scheme == "demka", url.host == "share" {
            shareId = url.pathComponents.first(where: { $0 != "/" })
        }
        guard let id = shareId, !id.isEmpty else { return }
        Task { await loadShare(id: id) }
    }

    @Published private(set) var currentShareId: String? = nil

    @MainActor private func loadShare(id: String, switchView: Bool = true) async {
        isLoadingShare = true
        shareError = nil
        do {
            let md = try await fetchFirestoreShare(id: id)
            markdown = md
            currentShareId = id
            if switchView { showEditor = false }
            rebuild()
        } catch {
            shareError = error.localizedDescription
        }
        isLoadingShare = false
    }

    @MainActor func refreshShare() async {
        guard let id = currentShareId else { return }
        isLoadingShare = true
        do {
            let md = try await fetchFirestoreShare(id: id)
            markdown = md
            rebuild()
        } catch {
            let msg = error.localizedDescription
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                shareError = msg
            }
        }
        isLoadingShare = false
    }

    @MainActor func createShare() async -> URL? {
        isCreatingShare = true
        shareError = nil
        do {
            let url = try await postFirestoreShare(markdown: markdown)
            isCreatingShare = false
            return url
        } catch {
            shareError = error.localizedDescription
            isCreatingShare = false
            return nil
        }
    }

    private func postFirestoreShare(markdown: String) async throws -> URL {
        let urlStr = "\(firestoreBase)/shares?key=\(firestoreKey)"
        guard let apiURL = URL(string: urlStr) else { throw URLError(.badURL) }
        let formatter = ISO8601DateFormatter()
        let body: [String: Any] = [
            "fields": [
                "md":        ["stringValue": markdown],
                "imgs":      ["mapValue": ["fields": [:] as [String: Any]]],
                "created":   ["timestampValue": formatter.string(from: Date())],
                "expiresAt": ["timestampValue": formatter.string(from: Date().addingTimeInterval(30 * 24 * 60 * 60))]
            ]
        ]
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "demka", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create share"])
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let name = json["name"] as? String,
              let id = name.components(separatedBy: "/").last, !id.isEmpty,
              let url = URL(string: "https://www.demka.in.ua/#share:\(id)") else {
            throw NSError(domain: "demka", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        return url
    }

    private func fetchFirestoreShare(id: String) async throws -> String {
        let urlStr = "\(firestoreBase)/shares/\(id)?key=\(firestoreKey)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        req.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "demka", code: 0, userInfo: [NSLocalizedDescriptionKey: "Share not found"])
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let fields = json["fields"] as? [String: Any],
              let mdField = fields["md"] as? [String: Any],
              let md = mdField["stringValue"] as? String else {
            throw NSError(domain: "demka", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid share data"])
        }
        return md
    }

    // MARK: - Export

    func exportMarkdown() -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("demka-\(exportStamp()).md")
        try? markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @MainActor
    func exportPDF() async -> URL? {
        isExportingPDF = true
        defer { isExportingPDF = false }

        let pageW: CGFloat = 1024
        let pageH: CGFloat = 576

        var images: [UIImage] = []
        for node in nodes {
            let view = CardExportView(node: node, theme: theme)
                .frame(width: pageW, height: pageH)
            let r = ImageRenderer(content: view)
            r.scale = 2.0
            r.proposedSize = ProposedViewSize(width: pageW, height: pageH)
            if let img = r.uiImage { images.append(img) }
        }

        guard !images.isEmpty else { return nil }

        let pageRect = CGRect(origin: .zero, size: CGSize(width: pageW, height: pageH))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("demka-\(exportStamp()).pdf")

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = pdfRenderer.pdfData { ctx in
            for img in images {
                ctx.beginPage()
                img.draw(in: pageRect)
            }
        }
        try? data.write(to: url)
        return url
    }

    private func exportStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }

    // MARK: - Private helpers
    private func markVisited(_ idx: Int) {
        guard idx < nodes.count else { return }
        visitedIds.insert(nodes[idx].id)
    }

    // MARK: - Default content
    static let defaultMarkdown = """
# demka

it is a simple text to slides generator

## why demka

- minimal
- free
- nothing to install

## how it works

- parse markdown into a node tree
- camera pans + zooms between them
- bullets reveal one at a time

# getting started

write headings and bullets in the editor

## heading levels

- # H1 starts a new section
- ## H2 adds a sub-topic
- ### H3 adds detail

## themes

- Stone — clean light
- Midnight — dark mode
- Amber — warm dark
"""
}
