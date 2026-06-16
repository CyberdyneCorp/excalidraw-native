import ExcalidrawGeometry
import ExcalidrawMath
import ExcalidrawModel
import Foundation

/// Tables: a grid of bound-text cells (built from the same container-text
/// primitive as sticky notes), grouped so they move and select as one unit.
public extension EditorController {
    private static var defaultCellWidth: Double {
        120
    }

    private static var defaultCellHeight: Double {
        44
    }

    /// Create a `rows × cols` table with its top-left at `point`, grouped, and
    /// select it. Each cell is a transparent rectangle with a centered,
    /// container-bound text label (edited via double-tap, like a sticky note).
    @discardableResult
    func createTable(at point: Point, rows: Int = 3, cols: Int = 3) -> String {
        let rows = max(rows, 1), cols = max(cols, 1)
        let cellW = Self.defaultCellWidth, cellH = Self.defaultCellHeight
        let groupID = nextID()
        store.transaction { scene in
            for row in 0 ..< rows {
                for col in 0 ..< cols {
                    addTableCell(
                        to: &scene, group: groupID,
                        x: point.x + Double(col) * cellW, y: point.y + Double(row) * cellH,
                        width: cellW, height: cellH
                    )
                }
            }
        }
        selectedIDs = groupSiblings(of: tableCells(group: groupID).first?.id ?? "")
        return groupID
    }

    /// Append a row of cells to the bottom of table `groupID`.
    func addTableRow(_ groupID: String) {
        let cells = tableCells(group: groupID)
        guard let any = cells.first else { return }
        let columns = Set(cells.map(\.base.x)).sorted()
        let cellH = any.base.height
        let bottom = cells.map { $0.base.y + $0.base.height }.max() ?? any.base.y
        store.transaction { scene in
            for x in columns {
                addTableCell(to: &scene, group: groupID, x: x, y: bottom, width: any.base.width, height: cellH)
            }
        }
    }

    /// Append a column of cells to the right of table `groupID`.
    func addTableColumn(_ groupID: String) {
        let cells = tableCells(group: groupID)
        guard let any = cells.first else { return }
        let rows = Set(cells.map(\.base.y)).sorted()
        let cellW = any.base.width
        let right = cells.map { $0.base.x + $0.base.width }.max() ?? any.base.x
        store.transaction { scene in
            for y in rows {
                addTableCell(to: &scene, group: groupID, x: right, y: y, width: cellW, height: any.base.height)
            }
        }
    }

    /// Whether `id` belongs to a table (for showing add-row/column actions).
    func tableGroupID(of id: String) -> String? {
        guard let element = scene.element(id: id), case let .string(group)? = element.base.customData?["table"]
        else { return nil }
        return group
    }

    /// The cell rectangles of table `groupID`, in reading order.
    private func tableCells(group: String) -> [ExcalidrawElement] {
        scene.visibleElements
            .filter { if case .string(group)? = $0.base.customData?["table"] { return true }; return false }
            .sorted { ($0.base.y, $0.base.x) < ($1.base.y, $1.base.x) }
    }

    private func addTableCell(
        to scene: inout Scene, group: String, x: Double, y: Double, width: Double, height: Double
    ) {
        let cellID = nextID()
        let textID = nextID()
        var cellBase = currentItem.makeBase(id: cellID, seed: nextSeed(), x: x, y: y)
        cellBase.width = width
        cellBase.height = height
        cellBase.backgroundColor = "transparent"
        cellBase.groupIds = [group]
        cellBase.boundElements = [BoundElement(id: textID, type: .text)]
        cellBase.customData = ["table": .string(group)]
        scene.add(ExcalidrawElement(base: cellBase, kind: .rectangle))

        var textBase = currentItem.makeBase(id: textID, seed: nextSeed(), x: x, y: y + height / 2)
        textBase.groupIds = [group]
        textBase.backgroundColor = "transparent"
        let props = TextProperties(
            fontSize: 16, fontFamily: currentItem.fontFamily, text: "",
            textAlign: .center, verticalAlign: .middle, containerId: cellID, autoResize: false
        )
        scene.add(ExcalidrawElement(base: textBase, kind: .text(props)))
    }
}
