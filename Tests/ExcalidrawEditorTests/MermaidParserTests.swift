import ExcalidrawMath
import ExcalidrawModel
import XCTest
@testable import ExcalidrawEditor

final class MermaidParserTests: XCTestCase {
    func testParsesNodesEdgesAndShapes() throws {
        let text = """
        flowchart TD
            A[Start] --> B{Decision}
            B -->|Yes| C(Go)
            B -->|No| D((Stop))
        """
        let elements = try XCTUnwrap(MermaidParser.parse(text))
        // 4 shapes + 4 bound text labels + 3 arrows.
        let shapes = elements.filter { ["rectangle", "diamond", "ellipse"].contains($0.type) }
        let texts = elements.filter { $0.type == "text" }
        let arrows = elements.filter { $0.type == "arrow" }
        XCTAssertEqual(shapes.count, 4)
        XCTAssertEqual(texts.count, 4)
        XCTAssertEqual(arrows.count, 3)

        // Shape mapping: A rectangle, B diamond, D ellipse.
        XCTAssertEqual(elements.first { $0.id == "mermaid-A" }?.type, "rectangle")
        XCTAssertEqual(elements.first { $0.id == "mermaid-B" }?.type, "diamond")
        XCTAssertEqual(elements.first { $0.id == "mermaid-D" }?.type, "ellipse")
    }

    func testEdgeLabelBecomesNoArrowheadForLine() throws {
        let elements = try XCTUnwrap(MermaidParser.parse("graph LR\n A --- B"))
        let arrow = try XCTUnwrap(elements.first { $0.type == "arrow" })
        if case let .arrow(props) = arrow.kind {
            XCTAssertNil(props.endArrowhead, "--- is a plain line")
        } else {
            XCTFail("expected an arrow element")
        }
    }

    func testArrowsBindToNodes() throws {
        let elements = try XCTUnwrap(MermaidParser.parse("flowchart TD\n A --> B"))
        let arrow = try XCTUnwrap(elements.first { $0.type == "arrow" })
        if case let .arrow(props) = arrow.kind {
            XCTAssertEqual(props.startBinding?.elementId, "mermaid-A")
            XCTAssertEqual(props.endBinding?.elementId, "mermaid-B")
            XCTAssertEqual(props.endArrowhead, .arrow)
        } else {
            XCTFail("expected an arrow element")
        }
    }

    func testTextLabelsAreContainerBound() throws {
        let elements = try XCTUnwrap(MermaidParser.parse("flowchart TD\n A[Hello] --> B[World]"))
        let label = try XCTUnwrap(elements.first { $0.id == "mermaid-A-text" })
        if case let .text(props) = label.kind {
            XCTAssertEqual(props.text, "Hello")
            XCTAssertEqual(props.containerId, "mermaid-A")
        } else {
            XCTFail("expected a text element")
        }
    }

    func testLayeringPlacesTargetBelowSource() throws {
        let elements = try XCTUnwrap(MermaidParser.parse("flowchart TD\n A --> B"))
        let a = try XCTUnwrap(elements.first { $0.id == "mermaid-A" })
        let b = try XCTUnwrap(elements.first { $0.id == "mermaid-B" })
        XCTAssertGreaterThan(b.base.y, a.base.y, "TD lays the target below the source")
    }

    func testNonMermaidTextReturnsNil() {
        XCTAssertNil(MermaidParser.parse("just some text\nnot a diagram"))
        XCTAssertNil(MermaidParser.parse(""))
    }
}
