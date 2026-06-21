import ExcalidrawMath
import ExcalidrawModel
import XCTest
@testable import ExcalidrawEditor

/// Regression for cross-device Mermaid sync: `insertMermaid` must re-id the
/// parser's deterministic ids ("mermaid-A", "mermaid-edge-0") through `nextID()`
/// so a diagram carries unique, peer-prefixed ids (like every other insert) and
/// doesn't collide in the element-LWW reconcile.
final class MermaidInsertTests: XCTestCase {
    func testInsertReidsWithPeerPrefixAndKeepsBindings() {
        let ec = EditorController()
        ec.idPrefix = "peerA-"
        XCTAssertTrue(ec.insertMermaid("flowchart TD\nA[Start] --> B{OK?}\nB --> C[Go]", at: Point(0, 0)))

        let elements = ec.scene.elements
        XCTAssertFalse(elements.isEmpty)
        let ids = Set(elements.map(\.id))

        for element in elements {
            XCTAssertTrue(element.id.hasPrefix("peerA-"), "‘\(element.id)’ should carry the peer prefix")
            XCTAssertFalse(element.id.hasPrefix("mermaid-"), "raw parser id ‘\(element.id)’ leaked")
            switch element.kind {
            case let .arrow(props):
                if let start = props.startBinding?.elementId {
                    XCTAssertTrue(ids.contains(start), "arrow start binding must resolve after re-id")
                }
                if let end = props.endBinding?.elementId {
                    XCTAssertTrue(ids.contains(end), "arrow end binding must resolve after re-id")
                }
            case let .text(props):
                if let container = props.containerId {
                    XCTAssertTrue(ids.contains(container), "bound text container must resolve after re-id")
                }
            default:
                break
            }
        }
    }

    func testTwoIdenticalInsertsProduceDisjointIDs() {
        let ec = EditorController()
        ec.idPrefix = "peerA-"
        XCTAssertTrue(ec.insertMermaid("flowchart TD\nA --> B", at: Point(0, 0)))
        XCTAssertTrue(ec.insertMermaid("flowchart TD\nA --> B", at: Point(300, 0)))

        // The bug: both inserts reused "mermaid-A"/"mermaid-edge-0", so the second
        // clobbered the first and neither survived a cross-device reconcile.
        let allIDs = ec.scene.elements.map(\.id)
        XCTAssertEqual(allIDs.count, Set(allIDs).count, "ids must be unique across repeated inserts")
    }
}
