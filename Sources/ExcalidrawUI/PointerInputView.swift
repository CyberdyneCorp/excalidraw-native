#if canImport(UIKit)
    import ExcalidrawEditor
    import SwiftUI
    import UIKit

    /// Captures raw `UITouch` input (pressure, pencil vs finger, palm rejection,
    /// two-finger pan/zoom) and forwards it to the `EditorModel`. SwiftUI gestures
    /// don't expose `force`/coalesced touches, so this drops to UIKit.
    struct PointerInputView: UIViewRepresentable {
        let model: EditorModel
        /// Apple Pencil hover location (17.5+ reports it while hovering), or `nil`
        /// when the pencil leaves the proximity zone. Drives the hover preview.
        var onHover: (CGPoint?) -> Void = { _ in }
        /// Apple Pencil Pro squeeze.
        var onSqueeze: () -> Void = {}

        func makeUIView(context _: Context) -> TouchCaptureView {
            let view = TouchCaptureView()
            view.model = model
            view.onHover = onHover
            view.onSqueeze = onSqueeze
            view.setUpPencil()
            return view
        }

        func updateUIView(_ view: TouchCaptureView, context _: Context) {
            view.model = model
            view.onHover = onHover
            view.onSqueeze = onSqueeze
        }
    }

    final class TouchCaptureView: UIView, UIPencilInteractionDelegate {
        var model: EditorModel?
        var onHover: (CGPoint?) -> Void = { _ in }
        var onSqueeze: () -> Void = {}

        private var pencilActive = false
        private var gesturing = false
        private var lastCentroid: CGPoint = .zero
        private var lastDistance: CGFloat = 0

        /// "Hold to snap": while drawing a freehand stroke, holding the pen still
        /// for this long finalizes the stroke and snaps it to a recognized shape.
        private let dwellInterval: TimeInterval = 0.6
        /// Movement under this (points) counts as "holding still", so the dwell
        /// timer isn't reset by Pencil jitter.
        private let dwellMoveThreshold: CGFloat = 6
        private var dwellTimer: Timer?
        private var lastDrawPoint: CGPoint = .zero
        private var recognizedViaDwell = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("not used")
        }

        /// Wire up Apple Pencil hover (a hover gesture, 16.1+; with z-offset on
        /// 17.5+) and Pencil Pro squeeze (`UIPencilInteraction`).
        func setUpPencil() {
            let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover))
            addGestureRecognizer(hover)
            let pencil = UIPencilInteraction()
            pencil.delegate = self
            addInteraction(pencil)
        }

        @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed: onHover(recognizer.location(in: self))
            default: onHover(nil)
            }
        }

        /// Pencil Pro squeeze (17.5+).
        @available(iOS 17.5, *)
        func pencilInteraction(_: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
            if squeeze.phase == .ended { onSqueeze() }
        }

        /// Older double-tap (kept so the interaction is useful pre-Pencil-Pro too).
        func pencilInteractionDidTap(_: UIPencilInteraction) {
            onSqueeze()
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            let all = event?.allTouches ?? touches
            if all.count >= 2 { beginGesture(all); return }
            guard let touch = touches.first else { return }
            if touch.type == .pencil { pencilActive = true }
            guard accept(touch) else { return }
            // Double-tap enters line/arrow point-editing or image crop mode.
            if touch.tapCount == 2 {
                model?.beginEditMode(at: touch.location(in: self))
                return
            }
            recognizedViaDwell = false
            forward(.down, touch)
            scheduleDwell(at: touch.location(in: self))
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            let all = event?.allTouches ?? touches
            if gesturing || all.count >= 2 { cancelDwell(); updateGesture(all); return }
            guard let touch = touches.first, accept(touch) else { return }
            forward(.move, touch)
            dwellMoved(to: touch.location(in: self))
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            endTouches(touches, event: event)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            endTouches(touches, event: event)
        }

        private func endTouches(_ touches: Set<UITouch>, event: UIEvent?) {
            cancelDwell()
            if gesturing {
                let remaining = (event?.allTouches ?? []).filter { $0.phase != .ended && $0.phase != .cancelled }
                if remaining.count < 2 {
                    gesturing = false
                    model?.endViewportGesture()
                }
            } else if let touch = touches.first, accept(touch) {
                // The dwell already finalized + recognized this stroke.
                if recognizedViaDwell { recognizedViaDwell = false } else { forward(.up, touch) }
            }
            let pencilStillDown = (event?.allTouches ?? []).contains {
                $0.type == .pencil && $0.phase != .ended && $0.phase != .cancelled
            }
            if !pencilStillDown { pencilActive = false }
        }

        /// Palm rejection: once a pencil is active, ignore finger touches.
        private func accept(_ touch: UITouch) -> Bool {
            !(pencilActive && touch.type != .pencil)
        }

        // MARK: Hold-to-snap dwell

        /// (Re)arm the dwell timer for the freehand stroke at `point`.
        private func scheduleDwell(at point: CGPoint) {
            guard let model, model.shapeRecognitionEnabled, model.isDrawingFreehand else { return }
            lastDrawPoint = point
            armDwellTimer()
        }

        /// On movement, only re-arm when the pen actually moved a meaningful
        /// distance. Apple Pencil streams events continuously (pressure/azimuth)
        /// even while held still, which would otherwise reset the timer forever.
        private func dwellMoved(to point: CGPoint) {
            guard dwellTimer != nil else { return }
            if hypot(point.x - lastDrawPoint.x, point.y - lastDrawPoint.y) > dwellMoveThreshold {
                lastDrawPoint = point
                armDwellTimer()
            }
        }

        private func armDwellTimer() {
            dwellTimer?.invalidate()
            let timer = Timer(timeInterval: dwellInterval, repeats: false) { [weak self] _ in
                self?.fireDwell()
            }
            // `.common` so it still fires while a touch is actively tracking the
            // run loop (the default mode is suspended during touch tracking).
            RunLoop.main.add(timer, forMode: .common)
            dwellTimer = timer
        }

        private func cancelDwell() {
            dwellTimer?.invalidate()
            dwellTimer = nil
        }

        private func fireDwell() {
            cancelDwell()
            guard let model, model.isDrawingFreehand else { return }
            // Finalize the in-progress stroke, then snap it to a clean shape.
            model.pointer(.up, at: lastDrawPoint, type: pencilActive ? .pen : .touch)
            if model.recognizeSelectedStroke() { recognizedViaDwell = true }
        }

        private func forward(_ phase: PointerPhase, _ touch: UITouch) {
            let type: PointerType = touch.type == .pencil ? .pen : .touch
            let pressure = touch.maximumPossibleForce > 0 ? Double(touch.force / touch.maximumPossibleForce) : 0.5
            model?.pointer(phase, at: touch.location(in: self), type: type, pressure: pressure)
        }

        // MARK: Two-finger pan / pinch

        private func beginGesture(_ touches: Set<UITouch>) {
            gesturing = true
            cancelDwell()
            model?.beginViewportGesture()
            let pts = touches.map { $0.location(in: self) }
            lastCentroid = centroid(pts)
            lastDistance = spread(pts, around: lastCentroid)
        }

        private func updateGesture(_ touches: Set<UITouch>) {
            let pts = touches.map { $0.location(in: self) }
            guard pts.count >= 2 else { return }
            let centroidNow = centroid(pts)
            let distanceNow = spread(pts, around: centroidNow)
            let translation = CGSize(width: centroidNow.x - lastCentroid.x, height: centroidNow.y - lastCentroid.y)
            let scale = lastDistance > 0 ? Double(distanceNow / lastDistance) : 1
            model?.panZoom(translation: translation, scale: scale)
            lastCentroid = centroidNow
            lastDistance = distanceNow
        }

        private func centroid(_ pts: [CGPoint]) -> CGPoint {
            guard !pts.isEmpty else { return .zero }
            let sum = pts.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            return CGPoint(x: sum.x / CGFloat(pts.count), y: sum.y / CGFloat(pts.count))
        }

        private func spread(_ pts: [CGPoint], around center: CGPoint) -> CGFloat {
            pts.reduce(0) { $0 + hypot($1.x - center.x, $1.y - center.y) } / CGFloat(max(pts.count, 1))
        }
    }
#endif
