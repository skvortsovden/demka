import SwiftUI
import Combine

private let kMarkdown = "demka.md"
private let kViewMode = "demka.viewMode"
private let kTheme    = "demka.theme"
private let kReveal   = "demka.reveal"
private let kTimer    = "demka.timer"
private let kCards    = "demka.cards"
private let kZoom     = "demka.zoom"

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
    @Published var isPresenting: Bool = false {
        didSet { if isPresenting { timerStart() } else { timerStop() } }
    }
    @Published var visitedIds: Set<String> = []
    @Published var revealEnabled: Bool {
        didSet { UserDefaults.standard.set(revealEnabled, forKey: kReveal) }
    }
    @Published var cardsVisible: Bool {
        didSet { UserDefaults.standard.set(cardsVisible, forKey: kCards) }
    }
    @Published var zoomEnabled: Bool {
        didSet { UserDefaults.standard.set(zoomEnabled, forKey: kZoom) }
    }
    @Published var timerEnabled: Bool {
        didSet {
            UserDefaults.standard.set(timerEnabled, forKey: kTimer)
            if isPresenting { timerEnabled ? timerStart() : timerStop() }
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

        rebuild()
    }

    // MARK: - Rebuild
    func rebuild() {
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
        if activeIndex >= flat.count { activeIndex = max(0, flat.count - 1) }
        bulletsShown = 0
        visitedIds = []
        fitAll()
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
        c += node.bullets.count
        return c
    }

    func zoomToReveal() {
        guard zoomEnabled, revealEnabled, activeIndex < nodes.count else { return }
        let node = nodes[activeIndex]
        let vw = viewportSize.width, vh = viewportSize.height
        let pad: CGFloat = 60
        var base = min(vw / (node.w + pad * 2), vh / (node.h + pad * 2))
        base = min(base, 1.55); base = max(base, 0.5)
        let s = base * 1.3
        let tx = vw / 2 - (node.x + node.w / 2) * s
        let ty = vh / 2 - (node.y + node.h / 2) * s
        withAnimation(.easeInOut(duration: 0.28)) {
            camScale = s
            camOffset = CGSize(width: tx, height: ty)
        }
    }

    func advance() {
        guard !nodes.isEmpty else { return }
        let cur = nodes[activeIndex]
        let tot = totalRevealSteps(for: cur)
        if revealEnabled && bulletsShown < tot {
            withAnimation(.easeOut(duration: 0.18)) { bulletsShown += 1 }
            zoomToReveal()
            return
        }
        if activeIndex < nodes.count - 1 {
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
            if bulletsShown == 0 { focusCamera(on: activeIndex, animated: true) }
            else { zoomToReveal() }
            return
        }
        if activeIndex > 0 {
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
        withAnimation(.easeInOut(duration: 0.32)) {
            activeIndex -= 1
            bulletsShown = 0
        }
        timerResetSlide()
        focusCamera(on: activeIndex, animated: true)
    }

    func activateNode(_ node: Node) {
        guard let idx = nodes.firstIndex(where: { $0.id == node.id }) else { return }
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
        let s = min(scaleX, scaleY, 1.0)
        camScale  = s
        camOffset = CGSize(width:  (vw - b.width  * s) / 2,
                           height: (vh - b.height * s) / 2)
    }

    func focusCamera(on idx: Int, animated: Bool) {
        guard idx < nodes.count else { return }
        let node = nodes[idx]
        let vw = viewportSize.width
        let vh = viewportSize.height
        let pad: CGFloat = 60
        var s = min(vw / (node.w + pad * 2), vh / (node.h + pad * 2))
        s = min(s, 1.55)
        s = max(s, 0.5)
        let tx = vw / 2 - (node.x + node.w / 2) * s
        let ty = vh / 2 - (node.y + node.h / 2) * s
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

    // MARK: - Share loading / creating
    @Published var isLoadingShare = false
    @Published var isCreatingShare = false
    @Published var shareError: String? = nil

    func handleIncomingURL(_ url: URL) {
        var id: String? = nil
        if let fragment = url.fragment, fragment.hasPrefix("share:") {
            id = String(fragment.dropFirst(6))
        } else if url.scheme == "demka", url.host == "share" {
            id = url.pathComponents.first(where: { $0 != "/" })
        }
        guard let shareId = id, !shareId.isEmpty else { return }
        Task { await loadShare(id: shareId) }
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
        let urlStr = "https://firestore.googleapis.com/v1/projects/demka-944f1/databases/(default)/documents/shares?key=AIzaSyBMQMTFQwWaqDcId-knFXw0Fh5VQCqQo3k"
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
        let urlStr = "https://firestore.googleapis.com/v1/projects/demka-944f1/databases/(default)/documents/shares/\(id)?key=AIzaSyBMQMTFQwWaqDcId-knFXw0Fh5VQCqQo3k"
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
