import Foundation
import CoreGraphics

enum FontSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }

    var label: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }

    var scale: CGFloat {
        switch self {
        case .small:  return 0.82
        case .medium: return 1.0
        case .large:  return 1.75
        }
    }

    // Concrete font sizes used in CardView
    var h1: CGFloat    { scale * 26 }
    var h2: CGFloat    { scale * 20 }
    var h3: CGFloat    { scale * 16 }
    var lede: CGFloat  { scale * 13 }
    var bullet: CGFloat      { scale * 12 }
    var bulletNum: CGFloat   { scale * 11 }
}

enum ViewMode: String, CaseIterable, Identifiable {
    case timeline, map, logic
    var id: String { rawValue }

    var label: String {
        switch self {
        case .timeline: return "Timeline"
        case .map:      return "Map"
        case .logic:    return "Logic"
        }
    }

    var symbol: String {
        switch self {
        case .timeline: return "→"
        case .map:      return "×"
        case .logic:    return "K"
        }
    }
}

enum LayoutEngine {
    // MARK: - Constants
    static var cardW: CGFloat = 280
    static let cardH: CGFloat = 180   // minimum / fallback height
    static let hGap: CGFloat  = 80
    static let vGap: CGFloat  = 50
    static let maxBullets     = 10
    // Non-zero in landscape: all cards get this fixed height instead of content-based sizing.
    static var landscapeCardH: CGFloat = 0
    static var fontSize: FontSize = .medium

    // MARK: - Content-aware height
    static func computeCardHeight(_ node: Node) -> CGFloat {
        if landscapeCardH > 0 { return landscapeCardH }
        var h: CGFloat = 14   // .padding(.top, 14) on titleText

        // Estimate how many lines the title needs given available card width.
        // charW scales with font: larger font → wider chars → fewer per line.
        let availW = max(80, cardW - 32)   // subtract horizontal padding (16 each side)
        let scale = fontSize.scale
        let charW: CGFloat
        let lineH: CGFloat
        switch node.level {
        case 1:  charW = 13.0 * scale; lineH = 36 * scale
        case 2:  charW = 10.0 * scale; lineH = 28 * scale
        default: charW =  7.5 * scale; lineH = 22 * scale
        }
        let charsPerLine = max(8, Int(availW / charW))
        let titleLines   = max(1, Int(ceil(Double(node.title.count) / Double(charsPerLine))))
        h += CGFloat(titleLines) * lineH
        h += 10   // .padding(.bottom, 10) on titleText

        let bulletCount = min(node.bullets.count, maxBullets)
        let hasBody = !node.lede.isEmpty || bulletCount > 0
        if hasBody {
            if !node.lede.isEmpty {
                h += 18 * scale
            }
            if bulletCount > 0 {
                if !node.lede.isEmpty { h += 6 }
                h += CGFloat(bulletCount) * 18 * scale
                h += CGFloat(bulletCount - 1) * 6
            }
            h += 12   // .padding(.bottom, 10) + small buffer
        }

        return max(80, h)
    }

    // MARK: - Timeline
    static func layoutTimeline(_ root: RootNode, resetHeights: Bool = true) {
        let all = root.flatten()
        guard !all.isEmpty else {
            root.bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
            return
        }
        for n in all { n.w = cardW; if resetHeights { n.h = computeCardHeight(n) } }

        let HEADER_MID: CGFloat = (cardH * 0.18).rounded()
        let ROW_Y: CGFloat      = -HEADER_MID
        let CHILD_GAP: CGFloat  = (vGap * 0.55).rounded()
        let SUB_GAP: CGFloat    = (vGap * 0.35).rounded()

        var xCur: CGFloat = 0
        for h1 in root.children {
            h1.x = xCur; h1.y = ROW_Y; h1.depth = 0
            xCur += cardW + hGap

            for h2 in h1.children {
                h2.x = xCur; h2.y = ROW_Y; h2.depth = 1

                var yCur: CGFloat = ROW_Y + h2.h + CHILD_GAP
                for h3 in h2.children {
                    h3.x = xCur; h3.y = yCur; h3.depth = 2
                    yCur += h3.h + SUB_GAP
                }
                xCur += cardW + hGap
            }
            xCur += hGap
        }

        applyBounds(root)
    }

    // MARK: - Map
    static func layoutMap(_ root: RootNode, resetHeights: Bool = true) {
        let all = root.flatten()
        guard !all.isEmpty else {
            root.bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
            return
        }
        for n in all { n.w = cardW; if resetHeights { n.h = computeCardHeight(n) } }

        let HDIST: CGFloat = cardW * 0.4
        let MVGAP: CGFloat = vGap * 0.5
        let VDIST: CGFloat = HDIST * 2

        func placeCol(_ nodes: [Node], side: String, x: CGFloat, centerY: CGFloat, depth: Int) {
            guard !nodes.isEmpty else { return }
            let totalH = nodes.reduce(CGFloat(0)) { $0 + $1.h } + CGFloat(nodes.count - 1) * MVGAP
            let startY = centerY - totalH / 2
            var yOff: CGFloat = 0
            for n in nodes {
                n.x = x
                n.y = startY + yOff
                n.depth = depth
                if !n.children.isEmpty {
                    let nx: CGFloat = side == "right"
                        ? n.x + cardW + HDIST
                        : n.x - HDIST - cardW
                    placeCol(n.children, side: side, x: nx, centerY: n.y + n.h / 2, depth: depth + 1)
                }
                yOff += n.h + MVGAP
            }
        }

        let colHalf: ([Node]) -> CGFloat = { ns in
            ns.isEmpty ? 0 : (ns.reduce(CGFloat(0)) { $0 + $1.h } + CGFloat(ns.count - 1) * MVGAP) / 2
        }

        let h1 = root.children[0]
        h1.x = -cardW / 2; h1.y = -h1.h / 2; h1.depth = 0

        let h2Kids = h1.children.filter { $0.level != 1 }
        let h1Kids = h1.children.filter { $0.level == 1 }

        let rCount     = Int(ceil(Double(h2Kids.count) / 2.0))
        let rightNodes = Array(h2Kids.prefix(rCount))
        let leftNodes  = Array(h2Kids.dropFirst(rCount))
        placeCol(rightNodes, side: "right", x: cardW / 2 + HDIST,           centerY: 0, depth: 1)
        placeCol(leftNodes,  side: "left",  x: -cardW / 2 - HDIST - cardW,  centerY: 0, depth: 1)

        if !h1Kids.isEmpty {
            let h2Bottom = max(h1.h / 2, colHalf(rightNodes), colHalf(leftNodes))
            var yKid = h2Bottom + VDIST

            for kid in h1Kids {
                kid.x = -cardW / 2; kid.y = yKid; kid.depth = 1
                let kidH2s  = kid.children
                let kRCount = Int(ceil(Double(kidH2s.count) / 2.0))
                let kidCY   = yKid + kid.h / 2
                placeCol(Array(kidH2s.prefix(kRCount)),    side: "right", x: cardW / 2 + HDIST,          centerY: kidCY, depth: 2)
                placeCol(Array(kidH2s.dropFirst(kRCount)), side: "left",  x: -cardW / 2 - HDIST - cardW, centerY: kidCY, depth: 2)
                let kidBottom = max(kid.h / 2,
                                   colHalf(Array(kidH2s.prefix(kRCount))),
                                   colHalf(Array(kidH2s.dropFirst(kRCount))))
                yKid += kid.h / 2 + kidBottom + VDIST
            }
        }

        resolveOverlaps(all, gap: MVGAP)
        applyBounds(root)
    }

    // MARK: - Logic
    static func layoutLogic(_ root: RootNode, resetHeights: Bool = true) {
        let all = root.flatten()
        guard !all.isEmpty else {
            root.bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
            return
        }
        for n in all { n.w = cardW; if resetHeights { n.h = computeCardHeight(n) } }

        let HDIST: CGFloat = cardW * 0.9
        let VDIST: CGFloat = vGap * 4

        func subH(_ n: Node) -> CGFloat {
            let kids = n.children.filter { $0.level != 1 }
            if kids.isEmpty { return n.h }
            let total = kids.reduce(CGFloat(0)) { $0 + subH($1) } + vGap * CGFloat(kids.count - 1)
            return max(n.h, total)
        }

        func place(_ n: Node, x: CGFloat, centerY: CGFloat, depth: Int) {
            n.depth = depth
            n.x = x
            n.y = centerY - n.h / 2
            let kids = n.children.filter { $0.level != 1 }
            guard !kids.isEmpty else { return }
            let totalH = kids.reduce(CGFloat(0)) { $0 + subH($1) } + vGap * CGFloat(kids.count - 1)
            var cy = centerY - totalH / 2
            for c in kids {
                let sh = subH(c)
                place(c, x: x + cardW + HDIST, centerY: cy + sh / 2, depth: depth + 1)
                cy += sh + vGap
            }
        }

        let h1 = root.children[0]
        let h1Kids = h1.children.filter { $0.level == 1 }

        var yOff: CGFloat = 0
        let sh = subH(h1)
        place(h1, x: 0, centerY: yOff + sh / 2, depth: 0)
        yOff += sh + VDIST

        for kid in h1Kids {
            let kidSh = subH(kid)
            place(kid, x: 0, centerY: yOff + kidSh / 2, depth: 1)
            yOff += kidSh + VDIST
        }

        resolveOverlaps(all, gap: vGap * 0.5)
        applyBounds(root)
    }

    // MARK: - Overlap resolution
    // Groups nodes by column (same x), sorts by y, then repeatedly pushes
    // any card that overlaps the one above it downward until every pair in
    // the column has at least `gap` points of vertical space.
    static func resolveOverlaps(_ all: [Node], gap: CGFloat) {
        var byX: [Int: [Node]] = [:]
        for n in all {
            byX[Int(n.x.rounded()), default: []].append(n)
        }
        for (_, col) in byX where col.count > 1 {
            let sorted = col.sorted { $0.y < $1.y }
            var changed = true
            while changed {
                changed = false
                for i in 1..<sorted.count {
                    let needed = sorted[i - 1].y + sorted[i - 1].h + gap
                    if sorted[i].y < needed {
                        sorted[i].y = needed
                        changed = true
                    }
                }
            }
        }
    }

    // MARK: - applyBounds
    static func applyBounds(_ root: RootNode) {
        let all = root.flatten()
        guard !all.isEmpty else {
            root.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
            return
        }
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for n in all {
            minX = min(minX, n.x); minY = min(minY, n.y)
            maxX = max(maxX, n.x + n.w); maxY = max(maxY, n.y + n.h)
        }
        let PAD: CGFloat = cardW * 0.18
        let offX = -minX + PAD
        let offY = -minY + PAD
        for n in all {
            n.x += offX
            n.y += offY
        }
        root.bounds = CGRect(x: 0, y: 0,
                             width:  (maxX - minX) + PAD * 2,
                             height: (maxY - minY) + PAD * 2)
    }

    // MARK: - promoteFirstAsRoot
    static func promoteFirstAsRoot(_ root: RootNode) {
        guard root.children.count > 1 else { return }
        let first = root.children[0]
        let rest  = Array(root.children.dropFirst())
        for n in rest { n.parent = first }
        first.children = first.children + rest
        root.children = [first]
    }
}
