import Foundation
import CoreGraphics

final class Node: Identifiable {
    let id: String
    let level: Int      // 1, 2, or 3
    var title: String
    var lede: String = ""
    var bullets: [Bullet] = []
    var notes: String = ""
    var children: [Node] = []
    weak var parent: Node?
    // layout
    var x: CGFloat = 0
    var y: CGFloat = 0
    var w: CGFloat = LayoutEngine.cardW
    var h: CGFloat = LayoutEngine.cardH
    var depth: Int = 0

    init(id: String, level: Int, title: String) {
        self.id = id
        self.level = level
        self.title = title
    }
}

struct Bullet: Identifiable {
    let id: UUID
    var text: String
    var num: Int?

    init(text: String, num: Int? = nil) {
        self.id = UUID()
        self.text = text
        self.num = num
    }
}

final class RootNode {
    var children: [Node] = []
    var bounds: CGRect = .zero  // set by layout engine

    func flatten() -> [Node] {
        var out: [Node] = []
        func walk(_ n: Node) {
            out.append(n)
            for c in n.children { walk(c) }
        }
        for top in children { walk(top) }
        return out
    }
}
