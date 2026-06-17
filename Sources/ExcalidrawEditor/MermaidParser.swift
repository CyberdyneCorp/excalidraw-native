import ExcalidrawGeometry
import ExcalidrawMath
import ExcalidrawModel
import Foundation

/// Parses a subset of Mermaid `flowchart`/`graph` syntax into Excalidraw
/// elements (shapes with bound text labels + bound arrows), laid out in layers
/// by the declared direction. Supports node shapes `[rect]`, `(rounded)`,
/// `([stadium])`, `{diamond}`, `((circle))` and edges `-->`, `---`, `-.->`,
/// `==>` with optional `|labels|`. Mirrors the intent of Excalidraw's
/// mermaid-to-excalidraw, in a self-contained Swift flowchart parser.
public enum MermaidParser {
    public enum Direction: String { case td, tb, bt, lr, rl }

    struct Node { var id: String; var label: String; var shape: Shape; var order: Int }
    enum Shape { case rectangle, rounded, diamond, ellipse }
    struct Edge { var from: String; var to: String; var label: String?; var arrow: Bool }

    private static let nodeWidth = 140.0
    private static let nodeHeight = 60.0
    private static let layerGap = 80.0
    private static let siblingGap = 40.0

    /// Parse `text` into elements, or `nil` when it isn't a recognizable
    /// flowchart (must start with `flowchart`/`graph`).
    public static func parse(_ text: String, seed: Int = 1) -> [ExcalidrawElement]? {
        var lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        lines = lines.filter { !$0.isEmpty && !$0.hasPrefix("%%") }
        guard let header = lines.first else { return nil }
        let lower = header.lowercased()
        guard lower.hasPrefix("flowchart") || lower.hasPrefix("graph") else { return nil }
        let direction = parseDirection(header)

        var nodes: [String: Node] = [:]
        var order = 0
        var edges: [Edge] = []
        func ensureNode(_ spec: NodeSpec) {
            if nodes[spec.id] == nil {
                nodes[spec.id] = Node(id: spec.id, label: spec.label ?? spec.id, shape: spec.shape, order: order)
                order += 1
            } else if let label = spec.label {
                nodes[spec.id]?.label = label
                nodes[spec.id]?.shape = spec.shape
            }
        }

        for line in lines.dropFirst() {
            if let (left, right, label, arrow) = parseEdge(String(line)) {
                ensureNode(left); ensureNode(right)
                edges.append(Edge(from: left.id, to: right.id, label: label, arrow: arrow))
            } else if let node = parseNodeSpec(String(line)) {
                ensureNode(node)
            }
        }
        guard !nodes.isEmpty else { return nil }

        let positions = layout(nodes: nodes, edges: edges, direction: direction)
        return build(nodes: nodes, edges: edges, positions: positions, seed: seed)
    }

    // MARK: - Parsing

    private static func parseDirection(_ header: String) -> Direction {
        let parts = header.split(separator: " ").map { $0.lowercased() }
        for token in parts.dropFirst() {
            if let dir = Direction(rawValue: token) { return dir }
        }
        return .td
    }

    struct NodeSpec { var id: String; var label: String?; var shape: Shape }

    /// `ID`, `ID[label]`, `ID(label)`, `ID([label])`, `ID{label}`, `ID((label))`.
    static func parseNodeSpec(_ raw: String) -> NodeSpec? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard let first = s.first, first.isLetter || first == "_" else { return nil }
        var id = ""
        var rest = Substring(s)
        for ch in s {
            if ch.isLetter || ch.isNumber || ch == "_" { id.append(ch); rest = rest.dropFirst() } else { break }
        }
        guard !id.isEmpty else { return nil }
        let body = rest.trimmingCharacters(in: .whitespaces)
        if body.isEmpty { return NodeSpec(id: id, label: nil, shape: .rectangle) }
        // Match the shape wrappers, longest first.
        let wrappers: [(open: String, close: String, shape: Shape)] = [
            ("((", "))", .ellipse), ("([", "])", .rounded), ("[", "]", .rectangle),
            ("{", "}", .diamond), ("(", ")", .rounded)
        ]
        for w in wrappers
            where body.hasPrefix(w.open) && body.hasSuffix(w.close) && body.count > w.open.count + w.close.count - 1 {
            let inner = String(body.dropFirst(w.open.count).dropLast(w.close.count))
            return NodeSpec(id: id, label: unquote(inner), shape: w.shape)
        }
        return NodeSpec(id: id, label: nil, shape: .rectangle)
    }

    /// `A --> B`, `A -->|label| B`, `A --- B`, `A -.-> B`, `A ==> B`.
    static func parseEdge(_ line: String) -> (NodeSpec, NodeSpec, String?, Bool)? {
        for op in ["-.->", "==>", "-->", "---"] {
            guard let range = line.range(of: op) else { continue }
            let leftStr = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            var rightStr = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            var label: String?
            if rightStr.hasPrefix("|"), let close = rightStr.dropFirst().firstIndex(of: "|") {
                label = unquote(String(rightStr[rightStr.index(after: rightStr.startIndex) ..< close]))
                rightStr = String(rightStr[rightStr.index(after: close)...]).trimmingCharacters(in: .whitespaces)
            }
            guard let left = parseNodeSpec(leftStr), let right = parseNodeSpec(rightStr) else { return nil }
            return (left, right, label, op != "---")
        }
        return nil
    }

    private static func unquote(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.count >= 2, t.hasPrefix("\""), t.hasSuffix("\"") { t = String(t.dropFirst().dropLast()) }
        return t
    }

    // MARK: - Layout

    private static func layout(
        nodes: [String: Node], edges: [Edge], direction: Direction
    ) -> [String: Point] {
        // Longest-path layering from roots (no incoming edges).
        var inDeg: [String: Int] = nodes.mapValues { _ in 0 }
        var outgoing: [String: [String]] = [:]
        for edge in edges where nodes[edge.from] != nil && nodes[edge.to] != nil {
            inDeg[edge.to, default: 0] += 1
            outgoing[edge.from, default: []].append(edge.to)
        }
        var layer: [String: Int] = [:]
        var queue = nodes.keys.filter { (inDeg[$0] ?? 0) == 0 }.sorted { nodes[$0]!.order < nodes[$1]!.order }
        for id in queue {
            layer[id] = 0
        }
        if queue.isEmpty, let first = nodes.keys.sorted(by: { nodes[$0]!.order < nodes[$1]!.order }).first {
            queue = [first]; layer[first] = 0 // cyclic graph: pick a start
        }
        var guardCount = 0
        while let id = queue.first, guardCount < nodes.count * nodes.count {
            queue.removeFirst(); guardCount += 1
            for next in outgoing[id] ?? [] {
                let candidate = (layer[id] ?? 0) + 1
                if candidate > (layer[next] ?? -1) { layer[next] = candidate; queue.append(next) }
            }
        }
        for id in nodes.keys where layer[id] == nil {
            layer[id] = 0
        }

        // Group by layer, position by direction.
        var byLayer: [Int: [String]] = [:]
        for (id, l) in layer {
            byLayer[l, default: []].append(id)
        }
        for key in byLayer.keys {
            byLayer[key]!.sort { nodes[$0]!.order < nodes[$1]!.order }
        }

        var positions: [String: Point] = [:]
        for (layerIndex, ids) in byLayer.sorted(by: { $0.key < $1.key }) {
            for (i, id) in ids.enumerated() {
                let along = Double(i) * (nodeWidth + siblingGap)
                let across = Double(layerIndex) * (nodeHeight + layerGap)
                positions[id] = position(along: along, across: across, direction: direction)
            }
        }
        return positions
    }

    private static func position(along: Double, across: Double, direction: Direction) -> Point {
        switch direction {
        case .td, .tb: Point(along, across)
        case .bt: Point(along, -across)
        case .lr: Point(across, along)
        case .rl: Point(-across, along)
        }
    }

    // MARK: - Element generation

    private static func build(
        nodes: [String: Node], edges: [Edge], positions: [String: Point], seed: Int
    ) -> [ExcalidrawElement] {
        var elements: [ExcalidrawElement] = []
        var seedCounter = seed
        func nextSeed() -> Int {
            seedCounter += 1; return seedCounter
        }
        var bounds: [String: BoundingBox] = [:]

        for node in nodes.values.sorted(by: { $0.order < $1.order }) {
            guard let pos = positions[node.id] else { continue }
            let elementID = "mermaid-\(node.id)"
            let textID = "mermaid-\(node.id)-text"
            var base = BaseProperties(id: elementID, x: pos.x, y: pos.y, width: nodeWidth, height: nodeHeight)
            base.seed = nextSeed()
            base.strokeColor = "#1e1e1e"
            base.backgroundColor = "#ffffff"
            base.roundness = node.shape == .rounded ? Roundness(type: 3) : nil
            base.boundElements = [BoundElement(id: textID, type: .text)]
            elements.append(ExcalidrawElement(base: base, kind: shapeKind(node.shape, base: base)))
            bounds[node.id] = BoundingBox(minX: pos.x, minY: pos.y, maxX: pos.x + nodeWidth, maxY: pos.y + nodeHeight)

            var textBase = BaseProperties(id: textID, x: pos.x, y: pos.y, width: nodeWidth, height: 25)
            textBase.seed = nextSeed()
            let text = TextProperties(
                fontSize: 16, text: node.label, textAlign: .center,
                verticalAlign: .middle, containerId: elementID, originalText: node.label
            )
            elements.append(ExcalidrawElement(base: textBase, kind: .text(text)))
        }

        for (index, edge) in edges.enumerated() {
            guard let from = bounds[edge.from], let to = bounds[edge.to] else { continue }
            elements.append(arrowElement(edge, index: index, from: from, to: to, seed: nextSeed()))
        }
        return elements
    }

    private static func shapeKind(_ shape: Shape, base _: BaseProperties) -> ElementKind {
        switch shape {
        case .rectangle, .rounded: .rectangle
        case .diamond: .diamond
        case .ellipse: .ellipse
        }
    }

    private static func arrowElement(
        _ edge: Edge, index: Int, from: BoundingBox, to: BoundingBox, seed: Int
    ) -> ExcalidrawElement {
        let start = Point((from.minX + from.maxX) / 2, from.maxY)
        let end = Point((to.minX + to.maxX) / 2, to.minY)
        var base = BaseProperties(
            id: "mermaid-edge-\(index)",
            x: start.x,
            y: start.y,
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        base.seed = seed
        base.strokeColor = "#1e1e1e"
        let props = ArrowProperties(
            points: [Point(0, 0), Point(end.x - start.x, end.y - start.y)],
            startBinding: FixedPointBinding(
                elementId: "mermaid-\(edge.from)", fixedPoint: Binding.fixedPoint(for: start, in: from), mode: .orbit
            ),
            endBinding: FixedPointBinding(
                elementId: "mermaid-\(edge.to)", fixedPoint: Binding.fixedPoint(for: end, in: to), mode: .orbit
            ),
            endArrowhead: edge.arrow ? .arrow : nil
        )
        return ExcalidrawElement(base: base, kind: .arrow(props))
    }
}
