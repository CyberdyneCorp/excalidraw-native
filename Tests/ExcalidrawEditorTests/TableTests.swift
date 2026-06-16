import ExcalidrawMath
import ExcalidrawModel
import XCTest
@testable import ExcalidrawEditor

final class TableTests: XCTestCase {
    private func cells(_ ec: EditorController) -> [ExcalidrawElement] {
        ec.scene.visibleElements.filter { if case .rectangle = $0.kind { return true }; return false }
    }

    func testCreateTableBuildsGridOfBoundCells() {
        let ec = EditorController()
        let group = ec.createTable(at: Point(0, 0), rows: 2, cols: 3)
        // 2×3 cells, each a rectangle + a bound text → 12 elements.
        XCTAssertEqual(ec.scene.visibleElements.count, 12)
        XCTAssertEqual(cells(ec).count, 6)
        for cell in cells(ec) {
            XCTAssertEqual(cell.base.groupIds, [group])
            XCTAssertEqual(cell.base.boundElements?.count, 1)
            XCTAssertEqual(ec.tableGroupID(of: cell.id), group)
        }
    }

    func testSelectingOneCellSelectsWholeTable() throws {
        let ec = EditorController()
        let group = ec.createTable(at: Point(0, 0), rows: 2, cols: 2)
        let oneCell = try XCTUnwrap(cells(ec).first)
        XCTAssertEqual(ec.groupSiblings(of: oneCell.id).count, 8) // 4 cells × 2 (rect+text)
        _ = group
    }

    func testAddRowAddsAColumnWorthOfCells() {
        let ec = EditorController()
        let group = ec.createTable(at: Point(0, 0), rows: 2, cols: 3)
        let before = cells(ec).count
        ec.addTableRow(group)
        XCTAssertEqual(cells(ec).count, before + 3) // one new cell per column
    }

    func testAddColumnAddsARowWorthOfCells() {
        let ec = EditorController()
        let group = ec.createTable(at: Point(0, 0), rows: 2, cols: 3)
        ec.addTableColumn(group)
        XCTAssertEqual(cells(ec).count, 2 * 3 + 2) // one new cell per row
    }

    func testCellTextIsEditableViaBoundTextHit() throws {
        let ec = EditorController()
        ec.createTable(at: Point(0, 0), rows: 1, cols: 1)
        // The single cell spans (0,0)-(120,44); its centre should resolve a label.
        let hit = ec.boundTextHit(at: Point(60, 22))
        XCTAssertNotNil(hit)
        try ec.setText(id: XCTUnwrap(hit?.text), "x")
        XCTAssertNotNil(try ec.scene.element(id: XCTUnwrap(hit?.text)))
    }

    func testCreateTableIsOneUndoStep() {
        let ec = EditorController()
        ec.createTable(at: Point(0, 0), rows: 2, cols: 2)
        XCTAssertTrue(ec.undo())
        XCTAssertTrue(ec.scene.visibleElements.isEmpty)
    }
}
