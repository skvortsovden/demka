import Foundation

/// Ports the JS parseMarkdown function exactly.
struct MarkdownParser {

    static func parse(_ src: String) -> RootNode {
        let lines = src.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        let root = RootNode()
        var stack: [AnyObject] = [root]  // RootNode or Node

        func currentNode() -> Node? { stack.last as? Node }
        func currentRoot() -> RootNode? { stack.last as? RootNode }

        func topOfDepth(_ d: Int) {
            while stack.count > 1 {
                if let n = stack.last as? Node, n.level >= d {
                    stack.removeLast()
                } else {
                    break
                }
            }
        }

        var inCode = false
        var inNotes = false
        var noteLines: [String] = []
        var currentBulletPath: [Bullet] = []

        for raw in lines {
            // Code fence
            if raw.hasPrefix("```") {
                inCode = !inCode
                continue
            }
            if inCode { continue }

            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            // Notes block (accumulate until closing ---)
            if inNotes {
                if trimmed == "---" {
                    currentNode()?.notes = noteLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    noteLines = []
                    inNotes = false
                } else {
                    noteLines.append(trimmed)
                }
                continue
            }

            // Single-line notes: ---text--- or --- text ---
            if trimmed.hasPrefix("---"), trimmed.hasSuffix("---"), trimmed.count > 6 {
                let inner = String(trimmed.dropFirst(3).dropLast(3)).trimmingCharacters(in: .whitespaces)
                if !inner.isEmpty { currentNode()?.notes = inner }
                continue
            }

            // Start of multi-line notes block
            if trimmed == "---" {
                inNotes = true
                noteLines = []
                continue
            }

            // Heading: #, ##, ###
            if let (level, text) = parseHeading(raw) {
                topOfDepth(level)
                let node = Node(id: uid(), level: level, title: text)
                if let parentNode = stack.last as? Node {
                    parentNode.children.append(node)
                    node.parent = parentNode
                } else if let parentRoot = stack.last as? RootNode {
                    parentRoot.children.append(node)
                }
                stack.append(node)
                currentBulletPath = []
                continue
            }

            // Bullet: "- text" or "N. text" with optional indent
            if let (indent, numMatch, text) = parseBullet(raw) {
                guard let cur = currentNode() else { continue }
                let depth = indent / 2
                let bullet = Bullet(text: text, num: numMatch)
                if depth == 0 {
                    cur.bullets.append(bullet)
                    currentBulletPath = [bullet]
                } else {
                    let parentIdx = depth - 1
                    if parentIdx < currentBulletPath.count {
                        // sub-bullets are flattened into the top-level list for iOS simplicity
                        cur.bullets.append(bullet)
                        currentBulletPath = Array(currentBulletPath.prefix(depth)) + [bullet]
                    } else if !cur.bullets.isEmpty {
                        cur.bullets.append(bullet)
                        currentBulletPath = [bullet]
                    } else {
                        cur.bullets.append(bullet)
                        currentBulletPath = [bullet]
                    }
                }
                continue
            }

            // Blank line
            if raw.trimmingCharacters(in: .whitespaces).isEmpty {
                currentBulletPath = []
                continue
            }

            // Paragraph line → lede of current heading
            if let cur = currentNode(), cur.bullets.isEmpty {
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                if cur.lede.isEmpty {
                    cur.lede = trimmed
                } else {
                    cur.lede += " " + trimmed
                }
            }
        }

        return root
    }

    // MARK: - Helpers

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        var idx = line.startIndex
        var count = 0
        while idx < line.endIndex && line[idx] == "#" && count < 3 {
            count += 1
            idx = line.index(after: idx)
        }
        guard count > 0, idx < line.endIndex, line[idx] == " " else { return nil }
        let rest = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return nil }
        return (count, rest)
    }

    private static func parseBullet(_ line: String) -> (indent: Int, num: Int?, text: String)? {
        // Regex: /^(\s*)([-*]|\d+\.)\s+(.+?)\s*$/
        let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).reduce(0) { acc, c in
            acc + (c == "\t" ? 2 : 1)
        }
        let stripped = String(line.dropFirst(indent))
        if stripped.hasPrefix("- ") || stripped.hasPrefix("* ") {
            let text = String(stripped.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return (indent, nil, text)
        }
        // Numbered: "1. text"
        let parts = stripped.split(separator: " ", maxSplits: 1)
        if parts.count == 2,
           let marker = parts.first,
           marker.hasSuffix("."),
           let n = Int(marker.dropLast()) {
            let text = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return (indent, n, text)
        }
        return nil
    }

    private static func uid() -> String {
        "n" + UUID().uuidString.prefix(7).lowercased()
    }
}
