import ExcalidrawGeometry
import ExcalidrawMath
import ExcalidrawModel
import Foundation

/// Elbow-arrow routing: recompute an orthogonal path for an arrow whose
/// `elbowed` flag is set, from its global endpoints and any bound shapes.
public extension EditorController {
    /// Set the elbow mode for newly created arrows and convert any selected
    /// arrows to/from elbow, re-routing as one undo step.
    func setElbowed(_ elbowed: Bool) {
        currentItem.elbowed = elbowed
        let arrowIDs = selectedElements.compactMap { element -> String? in
            if case .arrow = element.kind { return element.id }
            return nil
        }
        guard !arrowIDs.isEmpty else { return }
        store.transaction { scene in
            for id in arrowIDs {
                guard var arrow = scene.element(id: id), case var .arrow(props) = arrow.kind,
                      props.elbowed != elbowed, let first = props.points.first,
                      let last = props.points.last else { continue }
                props.elbowed = elbowed
                arrow.kind = .arrow(props)
                if elbowed {
                    let startGlobal = Point(arrow.base.x + first.x, arrow.base.y + first.y)
                    let endGlobal = Point(arrow.base.x + last.x, arrow.base.y + last.y)
                    Self.applyElbowRoute(to: &arrow, startGlobal: startGlobal, endGlobal: endGlobal, in: scene)
                }
                scene.replace(arrow)
            }
        }
    }

    /// Re-route the elbow arrow `id` from its current endpoints (called after
    /// creation and whenever an endpoint moves).
    func routeElbowArrow(_ id: String) {
        store.modifyScene { scene in
            guard var arrow = scene.element(id: id), case let .arrow(props) = arrow.kind, props.elbowed,
                  let first = props.points.first, let last = props.points.last else { return }
            let startGlobal = Point(arrow.base.x + first.x, arrow.base.y + first.y)
            let endGlobal = Point(arrow.base.x + last.x, arrow.base.y + last.y)
            Self.applyElbowRoute(to: &arrow, startGlobal: startGlobal, endGlobal: endGlobal, in: scene)
            scene.replace(arrow)
        }
    }

    /// Rewrite `arrow`'s points as the elbow route between two global endpoints,
    /// reanchoring its origin/size. No-op for non-elbow arrows. Shared by
    /// creation and the bound-arrow update pass.
    internal static func applyElbowRoute(
        to arrow: inout ExcalidrawElement, startGlobal: Point, endGlobal: Point, in scene: Scene
    ) {
        guard case var .arrow(props) = arrow.kind, props.elbowed else { return }
        let startBox = props.startBinding.flatMap { scene.element(id: $0.elementId) }.map { ElementGeometry.bounds($0) }
        let endBox = props.endBinding.flatMap { scene.element(id: $0.elementId) }.map { ElementGeometry.bounds($0) }
        let routed = ElbowArrow.route(start: startGlobal, startBox: startBox, end: endGlobal, endBox: endBox)
        let origin = routed.first ?? startGlobal
        props.points = routed.map { Point($0.x - origin.x, $0.y - origin.y) }
        arrow.base.x = origin.x
        arrow.base.y = origin.y
        let xs = props.points.map(\.x), ys = props.points.map(\.y)
        arrow.base.width = (xs.max() ?? 0) - (xs.min() ?? 0)
        arrow.base.height = (ys.max() ?? 0) - (ys.min() ?? 0)
        arrow.kind = .arrow(props)
    }
}
