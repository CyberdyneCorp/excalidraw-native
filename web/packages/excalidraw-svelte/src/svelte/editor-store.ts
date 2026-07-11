import {
  EditorController,
  type ElementStyle,
  type FlowchartDirection,
  type PointerPhase,
  type PointerType,
  type Tool,
  pointerEvent,
} from "../editor/index.js";
import { commonBounds, unrotatedOutline } from "../geometry/index.js";
import { Point } from "../math/index.js";
import {
  type Arrowhead,
  type ExcalidrawElement,
  type FillStyle,
  RoundnessType,
  Scene,
  SceneDocument,
  type StrokeStyle,
  type TextAlign,
} from "../model/index.js";
import type { Peer } from "../protocol/index.js";
import { reconcileElements } from "../protocol/index.js";
import {
  type OverlayColors,
  type RenderContext,
  type Theme,
  Viewport,
  ZOOM_RANGE,
  containsScene,
  renderOverlay as drawOverlay,
  exportSvg,
  extractScene,
  renderScene,
} from "../render/index.js";
import { CollabSession, type CollabSocket, type RemoteCursor } from "./collab-session.js";
import { TrailStore } from "./trail-store.js";

function nowSeconds(): number {
  return (typeof performance !== "undefined" ? performance.now() : 0) / 1000;
}

function clampZoom(zoom: number): number {
  return Math.min(Math.max(zoom, ZOOM_RANGE.min), ZOOM_RANGE.max);
}

export interface PointerOptions {
  type?: PointerType;
  pressure?: number;
  shift?: boolean;
  alt?: boolean;
  toggle?: boolean;
  /** Current time (seconds) for laser/eraser trails; defaults to `performance.now()`. */
  now?: number;
}

/**
 * Bridges the pure `EditorController` to a UI: forwards pointer events
 * (converting view → scene coordinates), owns the viewport, and bumps a
 * `revision` counter so the canvas redraws after each change. Plain TS so it is
 * unit-testable; a Svelte component wraps it in `$state`. (parity: EditorModel.swift)
 */
export class EditorStore {
  readonly controller: EditorController;
  readonly trail = new TrailStore();
  viewport: Viewport;
  revision = 0;
  theme: Theme = "light";
  zenMode = false;
  /** On-canvas text editing state (`null` when not editing). `viewW`/`viewH` size
   * the editor to a container (cell/sticky note); absent for free text. */
  editingText: {
    id: string;
    value: string;
    viewX: number;
    viewY: number;
    viewW?: number;
    viewH?: number;
  } | null = null;
  /** A label created by the current edit session (removed again if committed empty). */
  private pendingLabelID: string | null = null;
  /** Last pointer position (view coords) while the hand tool is dragging. */
  private handPanLast: Point | null = null;
  /** Chart editing state (`null` when not editing): plot kind + CSV data. */
  editingChart: {
    group: string;
    kind: "bar" | "line";
    values: string;
    viewX: number;
    viewY: number;
  } | null = null;
  /** Last known canvas size, for zoom-to-fit and generator placement. */
  canvasWidth = 1024;
  canvasHeight = 768;
  /** Active collaboration session (`null` when editing solo). */
  collab: CollabSession | null = null;
  /** Per-element version last broadcast, to send only what changed (and avoid echo). */
  private lastBroadcast = new Map<string, number>();
  /** Listeners notified after each local edit — used by external collaboration
   * adapters (e.g. the optional Yjs/CRDT adapter) to mirror edits to a `Y.Doc`. */
  private changeListeners = new Set<() => void>();
  /** Listeners notified of local cursor moves (scene coords) — external presence
   * adapters publish these as their own cursor. */
  private cursorListeners = new Set<(scene: Point) => void>();
  /** Remote cursors supplied by an external presence source (e.g. the Yjs
   * awareness bridge); merged with the LWW `remoteCursors` when rendering. */
  externalCursors: { color: string; name: string; x: number; y: number }[] = [];
  /** Interaction-overlay colour overrides (host/embedding configuration). */
  overlayColors: OverlayColors | undefined = undefined;

  constructor(scene: Scene = new Scene(), viewport: Viewport = new Viewport()) {
    this.controller = new EditorController(scene);
    this.controller.zoom = viewport.zoom;
    this.viewport = viewport;
  }

  private bump(): void {
    this.revision += 1;
    this.broadcastLocalChanges();
    for (const listener of this.changeListeners) listener();
  }

  get scene(): Scene {
    return this.controller.scene;
  }
  get activeTool(): Tool {
    return this.controller.activeTool;
  }
  get canUndo(): boolean {
    return this.controller.canUndo;
  }
  get canRedo(): boolean {
    return this.controller.canRedo;
  }
  get zoomPercent(): number {
    return Math.round(this.viewport.zoom * 100);
  }

  /** A short stats string for the current selection (size in points). */
  get selectionStats(): string | null {
    const b = this.controller.selectionBounds;
    if (b === null) return null;
    return `${Math.round(b.width)} × ${Math.round(b.height)}`;
  }

  /** Number of currently selected elements. */
  get selectedCount(): number {
    return this.controller.selectedIDs.size;
  }
  /** Whether the selection can be grouped (two or more elements). */
  get canGroupSelection(): boolean {
    return this.controller.selectedIDs.size >= 2;
  }
  /** Whether the selection contains at least one grouped element to ungroup. */
  get canUngroupSelection(): boolean {
    return this.controller.selectedElements.some((el) => el.groupIds.length > 0);
  }

  // MARK: Pointer input (view coordinates in)

  pointer(phase: PointerPhase, viewPoint: Point, opts: PointerOptions = {}): void {
    // A press on the canvas while the on-canvas text editor is open commits
    // the edit (like excalidraw) and is consumed — it must not draw, select,
    // or spawn another editor. (The canvas pointerdown fires before the
    // textarea's blur, so without this the text tool would open a second
    // editor and drop the first text.)
    if (this.editingText !== null) {
      if (phase === "down") this.commitText();
      return;
    }
    // The text tool taps to place an on-canvas editor instead of dragging.
    if (this.activeTool === "text" && phase === "down") {
      this.beginText(viewPoint);
      return;
    }
    // The hand tool grabs the canvas: drags pan the viewport and never reach
    // the editor (parity with excalidraw's hand tool).
    if (this.activeTool === "hand") {
      if (phase === "down") {
        this.handPanLast = viewPoint;
      } else if (phase === "move" && this.handPanLast !== null) {
        this.panZoom(viewPoint.x - this.handPanLast.x, viewPoint.y - this.handPanLast.y, 1);
        this.handPanLast = viewPoint;
      } else if (phase === "up") {
        this.handPanLast = null;
      }
      return;
    }

    const scenePoint = this.viewport.viewToScene(viewPoint);
    const now = opts.now ?? nowSeconds();

    // The laser pointer only paints a fading trail — it creates/selects nothing.
    if (this.activeTool === "laser") {
      if (phase !== "up") this.trail.addLaser(scenePoint, now);
      this.bump();
      return;
    }
    // The eraser paints a trail AND still erases (forwarded below).
    if (this.activeTool === "eraser" && phase !== "up") {
      this.trail.addEraser(scenePoint, now);
    }

    const event = pointerEvent(scenePoint, phase, {
      type: opts.type,
      pressure: opts.pressure,
      shift: opts.shift,
      alt: opts.alt,
      toggleSelection: opts.toggle,
    });
    if (phase === "down") this.controller.pointerDown(event);
    else if (phase === "move") this.controller.pointerMove(event);
    else this.controller.pointerUp(event);
    // Keep the suggested-binding highlight live while drawing a linear element
    // or dragging a linear-edit endpoint; clear it when the drag ends.
    this.controller.updateSuggestedBinding(phase === "up" ? null : scenePoint, true);
    this.bump();

    if (this.collab !== null) {
      this.collab.sendPointer({ x: scenePoint.x, y: scenePoint.y });
      if (phase === "up") {
        this.collab.sendPresence({
          pointer: { x: scenePoint.x, y: scenePoint.y },
          selectedIds: [...this.controller.selectedIDs],
          tool: this.activeTool,
        });
      }
    }
  }

  /** Broadcast the cursor without a click — for hover/move tracking from the UI.
   * Notifies both the LWW session and any external presence adapter. */
  trackPointer(viewPoint: Point): void {
    const p = this.viewport.viewToScene(viewPoint);
    this.lastScenePoint = p;
    for (const listener of this.cursorListeners) listener(p);
    if (this.collab !== null) this.collab.sendPointer({ x: p.x, y: p.y });
    // Hovering with a linear tool suggests the bindable shape under the cursor,
    // and a click-started (pending) arrow's end follows the cursor live.
    const suggested = this.controller.updateSuggestedBinding(p);
    const pending = this.controller.updatePendingLinear(p);
    if (suggested || pending) this.bump();
  }

  /**
   * The element under a view point, if any — the host uses this to choose the
   * element vs empty-canvas context menu (and to select what was right-clicked).
   */
  elementAtView(viewPoint: Point): string | null {
    return this.controller.hitElement(this.viewport.viewToScene(viewPoint));
  }

  /** Select a single element by id (right-click selects what it targets). */
  selectOnly(id: string): void {
    this.controller.selectedIDs = new Set([id]);
    this.bump();
  }

  /** Abandon a click-started arrow awaiting its destination (Escape). */
  cancelPendingArrow(): boolean {
    if (!this.controller.cancelPendingLinear()) return false;
    this.bump();
    return true;
  }

  // MARK: Viewport

  panZoom(translationX: number, translationY: number, scale = 1): void {
    const v = this.viewport;
    v.zoom = clampZoom(v.zoom * scale);
    v.scrollX += translationX / v.zoom;
    v.scrollY += translationY / v.zoom;
    this.controller.zoom = v.zoom;
    this.bump();
  }

  /** Zoom by `scale` while keeping the scene point under the given view-space
   * cursor fixed — so wheel-zoom homes in on what's under the pointer. */
  zoomAtScreenPoint(viewX: number, viewY: number, scale: number): void {
    const v = this.viewport;
    const z0 = v.zoom;
    const z1 = clampZoom(z0 * scale);
    if (z1 === z0) return;
    v.scrollX += viewX / z1 - viewX / z0;
    v.scrollY += viewY / z1 - viewY / z0;
    v.zoom = z1;
    this.controller.zoom = z1;
    this.bump();
  }

  zoomTo(zoom: number): void {
    this.viewport.zoom = clampZoom(zoom);
    this.controller.zoom = this.viewport.zoom;
    this.bump();
  }
  zoomIn(): void {
    this.zoomTo(this.viewport.zoom * 1.2);
  }
  zoomOut(): void {
    this.zoomTo(this.viewport.zoom / 1.2);
  }
  /** Fit all content in the viewport (Shift+1 in excalidraw). */
  zoomToFit(margin = 40): void {
    const box = commonBounds(this.scene.visibleElements);
    if (box === null) return;
    const zoom = clampZoom(
      Math.min(
        (this.canvasWidth - 2 * margin) / Math.max(box.width, 1),
        (this.canvasHeight - 2 * margin) / Math.max(box.height, 1),
        1,
      ),
    );
    this.viewport.zoom = zoom;
    this.controller.zoom = zoom;
    this.viewport.scrollX = this.canvasWidth / (2 * zoom) - (box.minX + box.maxX) / 2;
    this.viewport.scrollY = this.canvasHeight / (2 * zoom) - (box.minY + box.maxY) / 2;
    this.bump();
  }

  resetZoom(): void {
    this.zoomTo(1);
  }

  // MARK: Tool + style commands

  selectTool(tool: Tool): void {
    this.controller.setTool(tool);
    this.bump();
  }

  private applyToSelection(change: (el: ExcalidrawElement) => void): void {
    this.controller.updateSelected(change);
    this.bump();
  }

  setStrokeColor(color: string): void {
    this.controller.currentItem.strokeColor = color;
    this.applyToSelection((el) => {
      el.strokeColor = color;
    });
  }
  setStrokeWidth(width: number): void {
    this.controller.currentItem.strokeWidth = width;
    this.applyToSelection((el) => {
      el.strokeWidth = width;
    });
  }
  setBackgroundColor(color: string): void {
    this.controller.currentItem.backgroundColor = color;
    this.applyToSelection((el) => {
      el.backgroundColor = color;
    });
  }
  setFillStyle(style: FillStyle): void {
    this.controller.currentItem.fillStyle = style;
    this.applyToSelection((el) => {
      el.fillStyle = style;
    });
  }
  setStrokeStyle(style: StrokeStyle): void {
    this.controller.currentItem.strokeStyle = style;
    this.applyToSelection((el) => {
      el.strokeStyle = style;
    });
  }
  setOpacity(opacity: number): void {
    this.controller.currentItem.opacity = opacity;
    this.applyToSelection((el) => {
      el.opacity = opacity;
    });
  }
  setRoughness(roughness: number): void {
    this.controller.currentItem.roughness = roughness;
    this.applyToSelection((el) => {
      el.roughness = roughness;
    });
  }
  setRoundEdges(round: boolean): void {
    this.controller.currentItem.roundEdges = round;
    this.applyToSelection((el) => {
      el.roundness = round ? { type: RoundnessType.adaptiveRadius } : null;
    });
  }
  setElbowed(elbowed: boolean): void {
    this.controller.setElbowed(elbowed);
    this.bump();
  }
  setStartArrowhead(head: Arrowhead | null): void {
    this.controller.currentItem.startArrowhead = head;
    this.applyToSelection((el) => {
      if (el.type === "arrow") el.startArrowhead = head;
    });
  }
  setEndArrowhead(head: Arrowhead | null): void {
    this.controller.currentItem.endArrowhead = head;
    this.applyToSelection((el) => {
      if (el.type === "arrow") el.endArrowhead = head;
    });
  }
  /** Arrow type maps onto the standard fields: straight → no roundness,
   * curved → proportional roundness, elbow → `elbowed` (with rerouting). */
  setArrowType(type: "straight" | "curved" | "elbow"): void {
    this.controller.currentItem.arrowCurved = type === "curved";
    if (type === "elbow") {
      this.controller.setElbowed(true);
      this.bump();
      return;
    }
    this.controller.setElbowed(false);
    const roundness = type === "curved" ? { type: RoundnessType.proportionalRadius } : null;
    this.applyToSelection((el) => {
      if (el.type === "arrow" || el.type === "line") el.roundness = roundness;
    });
  }
  setFontFamily(family: number): void {
    this.controller.currentItem.fontFamily = family;
    this.controller.updateSelectedText((t) => {
      t.fontFamily = family;
    });
    this.bump();
  }
  setFontSize(size: number): void {
    this.controller.currentItem.fontSize = size;
    this.controller.updateSelectedText((t) => {
      t.fontSize = size;
    });
    this.bump();
  }
  setTextAlign(align: TextAlign): void {
    this.controller.currentItem.textAlign = align;
    this.controller.updateSelectedText((t) => {
      t.textAlign = align;
    });
    this.bump();
  }
  toggleSnap(): void {
    this.controller.snapEnabled = !this.controller.snapEnabled;
    this.bump();
  }

  /** Whether finishing an element keeps the drawing tool active. */
  get toolLocked(): boolean {
    return this.controller.toolLocked;
  }
  toggleToolLock(): void {
    this.controller.toolLocked = !this.controller.toolLocked;
    this.bump();
  }

  // MARK: Clipboard & styles

  /** Last pointer position in scene coords — where pasted content lands. */
  private lastScenePoint: Point | null = null;
  /** Style captured by `copyStyles`, applied by `pasteStyles`. */
  private copiedStyle: ElementStyle | null = null;

  get hasCopiedStyles(): boolean {
    return this.copiedStyle !== null;
  }

  /** Serialize the selection as an `.excalidraw` payload (null when empty). */
  copySelection(): string | null {
    return this.controller.copyData();
  }

  /** Copy the selection, then delete it — one undo step. */
  cutSelection(): string | null {
    const data = this.controller.copyData();
    if (data === null) return null;
    this.controller.deleteSelected();
    this.bump();
    return data;
  }

  /** Paste an `.excalidraw` payload, centred at `at` (or the last cursor). */
  pasteJSON(json: string, at: Point | null = null): void {
    const before = new Set(this.scene.elements.map((e) => e.id));
    this.controller.paste(json);
    const target = at ?? this.lastScenePoint;
    if (target !== null) this.centreNewElements(before, target);
    this.bump();
  }

  /** Insert an image (from the clipboard) at `at` or the last cursor. */
  pasteImage(
    dataURL: string,
    mime: string,
    width: number,
    height: number,
    at: Point | null = null,
  ): void {
    const before = new Set(this.scene.elements.map((e) => e.id));
    // `insertImage` scales the bitmap and centres it in the viewport; re-centre
    // the result on the paste target.
    this.insertImage(dataURL, mime, width, height);
    const target = at ?? this.lastScenePoint;
    if (target !== null) this.centreNewElements(before, target);
    this.bump();
  }

  /** Insert pasted plain text as a text element at `at` or the last cursor. */
  pasteText(text: string, at: Point | null = null): void {
    const target = at ?? this.lastScenePoint ?? new Point(0, 0);
    const id = this.controller.createText(target);
    this.controller.setText(id, text);
    this.bump();
  }

  /** Move elements added since `before` so their bounds centre lands on `at`. */
  private centreNewElements(before: Set<string>, at: Point): void {
    const added = this.scene.elements.filter((e) => !before.has(e.id));
    if (added.length === 0) return;
    const box = commonBounds(added);
    if (box === null) return;
    const dx = at.x - (box.minX + box.maxX) / 2;
    const dy = at.y - (box.minY + box.maxY) / 2;
    this.controller.updateSelected((el) => {
      el.x += dx;
      el.y += dy;
    });
  }

  /** Capture the first selected element's style. */
  copyStyles(): boolean {
    const first = this.controller.selectedElements[0];
    if (first === undefined) return false;
    this.copiedStyle = this.controller.styleOf(first.id);
    return this.copiedStyle !== null;
  }

  /** Apply the captured style to the selection (one undo step). */
  pasteStyles(): void {
    if (this.copiedStyle === null) return;
    this.controller.applyStyle(this.copiedStyle);
    this.bump();
  }

  /** Wrap the selection in a frame that adopts it. */
  wrapSelectionInFrame(): void {
    this.controller.wrapSelectionInFrame();
    this.bump();
  }

  /** Clear the whole scene as one undoable step. */
  resetScene(): void {
    this.controller.setTool("selection");
    this.controller.selectAll();
    this.controller.deleteSelected();
    this.bump();
  }

  /** Open a PNG with an embedded scene; returns whether one was found. */
  openPngScene(bytes: Uint8Array): boolean {
    if (!containsScene(bytes)) return false;
    const scene = extractScene(bytes);
    if (scene === null) return false;
    this.controller.load(scene);
    this.bump();
    return true;
  }

  // MARK: Edit + history

  undo(): void {
    this.controller.undo();
    this.bump();
  }
  redo(): void {
    this.controller.redo();
    this.bump();
  }
  deleteSelected(): void {
    this.controller.deleteSelected();
    this.bump();
  }
  duplicate(): void {
    this.controller.duplicate();
    this.bump();
  }
  group(): void {
    this.controller.group();
    this.bump();
  }
  ungroup(): void {
    this.controller.ungroup();
    this.bump();
  }
  selectAll(): void {
    this.controller.selectAll();
    this.bump();
  }
  align(alignment: Parameters<EditorController["align"]>[0]): void {
    this.controller.align(alignment);
    this.bump();
  }
  flip(horizontal: boolean): void {
    this.controller.flip(horizontal);
    this.bump();
  }
  /** Attach (or clear, with `null`) a hyperlink on the selection. */
  setLink(url: string | null): void {
    this.controller.setLink(url);
    this.bump();
  }
  setLocked(locked: boolean): void {
    this.controller.setLocked(locked);
    this.bump();
  }
  reorder(order: Parameters<EditorController["reorder"]>[0]): void {
    this.controller.reorder(order);
    this.bump();
  }

  /** Insert an image (downscaled to a max dimension) at the viewport centre.
   * Returns the new element's image `fileId` so a host can broker the bytes to
   * peers (the collab stream carries only the element, never the binary). */
  insertImage(
    dataURL: string,
    mimeType: string,
    naturalWidth: number,
    naturalHeight: number,
  ): string {
    const scale = Math.min(1, 320 / Math.max(naturalWidth, naturalHeight, 1));
    const w = naturalWidth * scale;
    const h = naturalHeight * scale;
    const c = this.viewportCenterScene();
    const elId = this.controller.insertImage(
      dataURL,
      mimeType,
      new Point(c.x - w / 2, c.y - h / 2),
      w,
      h,
    );
    this.bump();
    const el = this.scene.element(elId);
    return el?.type === "image" ? (el.fileId ?? "") : "";
  }

  // MARK: Generators (placed at the viewport centre)

  private viewportCenterScene(): Point {
    return this.viewport.viewToScene(new Point(this.canvasWidth / 2, this.canvasHeight / 2));
  }
  insertStickyNote(): void {
    const { container, text } = this.controller.createStickyNote(this.viewportCenterScene());
    this.beginBoundTextEdit(container, text);
    this.bump();
  }
  insertTable(rows = 3, cols = 3): void {
    this.controller.createTable(this.viewportCenterScene(), rows, cols);
    this.bump();
  }

  /** The table group id of the current selection, if it is (part of) a table. */
  get selectedTableGroup(): string | null {
    for (const id of this.controller.selectedIDs) {
      const group = this.controller.tableGroupID(id);
      if (group !== null) return group;
    }
    return null;
  }

  /** Append a row to the selected table (no-op if no table is selected). */
  addTableRow(): void {
    const group = this.selectedTableGroup;
    if (group === null) return;
    this.controller.addTableRow(group);
    this.reselectTable(group);
    this.bump();
  }

  /** Append a column to the selected table (no-op if no table is selected). */
  addTableColumn(): void {
    const group = this.selectedTableGroup;
    if (group === null) return;
    this.controller.addTableColumn(group);
    this.reselectTable(group);
    this.bump();
  }

  /** Re-select the whole table group so the selection grows with new cells. */
  private reselectTable(group: string): void {
    const ids = this.scene.visibleElements
      .filter((el) => this.controller.tableGroupID(el.id) === group)
      .map((el) => el.id);
    this.controller.selectedIDs = new Set(ids);
  }
  insertChart(values: number[], kind: "bar" | "line" = "bar"): void {
    this.controller.createChart(this.viewportCenterScene(), values, [], kind);
    this.bump();
  }
  insertMermaid(text: string): boolean {
    const ok = this.controller.insertMermaid(text, this.viewportCenterScene());
    this.bump();
    return ok;
  }
  // MARK: Smart canvas (quick-create guard, grid/snap, content helpers)

  /** Whether flowchart quick-create applies: exactly one bindable shape. */
  get canQuickCreate(): boolean {
    const selected = this.controller.selectedElements;
    if (selected.length !== 1) return false;
    const el = selected[0]!;
    return el.type === "rectangle" || el.type === "diamond" || el.type === "ellipse";
  }

  /** Object/gap snapping while dragging (host toggle). */
  get snapEnabled(): boolean {
    return this.controller.snapEnabled;
  }
  /** Background grid (host toggle; the renderer takes the size). */
  gridEnabled = false;
  toggleGrid(): void {
    this.gridEnabled = !this.gridEnabled;
    this.bump();
  }

  /** Whether the scene has content and none of it is inside the viewport. */
  get contentOffscreen(): boolean {
    const box = commonBounds(this.scene.visibleElements);
    if (box === null) return false;
    const topLeft = this.viewport.viewToScene(new Point(0, 0));
    const bottomRight = this.viewport.viewToScene(new Point(this.canvasWidth, this.canvasHeight));
    return (
      box.maxX < topLeft.x ||
      box.minX > bottomRight.x ||
      box.maxY < topLeft.y ||
      box.minY > bottomRight.y
    );
  }

  /** Bring the content back into view (the scroll-back pill). */
  scrollToContent(): void {
    this.zoomToFit();
  }

  addFlowchartNode(direction: FlowchartDirection): void {
    const id = [...this.controller.selectedIDs][0];
    if (id !== undefined) this.controller.addFlowchartNode(id, direction);
    this.bump();
  }
  recognizeSelectedStroke(): void {
    const id = [...this.controller.selectedIDs][0];
    if (id !== undefined) this.controller.recognizeFreedraw(id);
    this.bump();
  }

  // MARK: On-canvas text editing

  beginText(viewPoint: Point): void {
    const id = this.controller.createText(this.viewport.viewToScene(viewPoint));
    this.editingText = { id, value: "", viewX: viewPoint.x, viewY: viewPoint.y };
    this.bump();
  }

  /**
   * Begin editing the text bound to a container (e.g. a sticky note), placing
   * the on-canvas editor over the container. Used after inserting a sticky note
   * and when double-clicking an existing one.
   */
  private beginBoundTextEdit(containerId: string, textId: string): void {
    const container = this.scene.element(containerId);
    const text = this.scene.element(textId);
    if (container === undefined || text === undefined || text.type !== "text") return;
    const tl = this.viewport.sceneToView(new Point(container.x, container.y));
    const br = this.viewport.sceneToView(
      new Point(container.x + container.width, container.y + container.height),
    );
    // Size the editor to the container so a table cell / note label doesn't
    // overflow to the right of its box.
    this.editingText = {
      id: textId,
      value: text.text,
      viewX: tl.x,
      viewY: tl.y,
      viewW: br.x - tl.x,
      viewH: br.y - tl.y,
    };
  }

  /**
   * If a container with bound text is hit at `viewPoint` (a double-click),
   * begin editing its label. Returns whether editing started.
   */
  editBoundTextAt(viewPoint: Point): boolean {
    const hit = this.controller.boundTextHit(this.viewport.viewToScene(viewPoint));
    if (hit === null) return false;
    this.beginBoundTextEdit(hit.container, hit.text);
    this.bump();
    return true;
  }

  /**
   * Double-click handler, in priority order: edit an existing bound label,
   * edit a chart, enter linear point ("spline") editing on a line/arrow, edit
   * a free text element, add a label to a hit container (created on the spot),
   * or — on empty canvas — create a new text element and edit it.
   */
  doubleClickAt(viewPoint: Point): void {
    if (this.editBoundTextAt(viewPoint)) return;
    const scenePoint = this.viewport.viewToScene(viewPoint);
    const chartGroup = this.controller.chartGroupAt(scenePoint);
    if (chartGroup !== null) {
      this.beginChartEdit(chartGroup, viewPoint);
      return;
    }
    if (this.controller.beginLinearEdit(scenePoint)) {
      this.bump();
      return;
    }
    const freeText = this.controller.unboundTextHit(scenePoint);
    if (freeText !== null) {
      this.beginExistingTextEdit(freeText);
      return;
    }
    const containerID = this.controller.labelContainerHit(scenePoint);
    if (containerID !== null) {
      const textID = this.controller.createBoundLabel(containerID);
      if (textID !== null) {
        this.pendingLabelID = textID;
        this.beginBoundTextEdit(containerID, textID);
        this.bump();
        return;
      }
    }
    this.beginText(viewPoint);
  }

  /** Open the on-canvas editor over an existing free text element. */
  private beginExistingTextEdit(id: string): void {
    const el = this.scene.element(id);
    if (el === undefined || el.type !== "text") return;
    const tl = this.viewport.sceneToView(new Point(el.x, el.y));
    this.editingText = { id, value: el.text, viewX: tl.x, viewY: tl.y };
    this.bump();
  }

  /** Whether a line/arrow is currently in point-editing mode (for the UI). */
  get isLinearEditing(): boolean {
    return this.controller.editingLinearID !== null;
  }

  // MARK: Chart editing (double-click a chart to change plot type + data)

  private beginChartEdit(group: string, viewPoint: Point): void {
    const info = this.controller.chartInfo(group);
    if (info === null) return;
    this.editingChart = {
      group,
      kind: info.kind,
      values: info.values.join(", "),
      viewX: viewPoint.x,
      viewY: viewPoint.y,
    };
    this.bump();
  }

  setChartKind(kind: "bar" | "line"): void {
    if (this.editingChart !== null) this.editingChart = { ...this.editingChart, kind };
  }
  setChartValues(values: string): void {
    if (this.editingChart !== null) this.editingChart = { ...this.editingChart, values };
  }

  /** Apply the edited plot type + data, rebuilding the chart in place. */
  commitChart(): void {
    if (this.editingChart === null) return;
    const values = this.editingChart.values
      .split(",")
      .map((s) => Number.parseFloat(s.trim()))
      .filter((v) => Number.isFinite(v));
    if (values.length > 0) {
      this.controller.updateChart(this.editingChart.group, this.editingChart.kind, values);
    }
    this.editingChart = null;
    this.bump();
  }

  cancelChart(): void {
    this.editingChart = null;
    this.bump();
  }

  // MARK: Collaboration

  /**
   * Join a collaboration room over `socket`. Local edits broadcast as
   * `element-updates`; remote edits are reconciled into the scene by
   * `version`/`versionNonce`. Returns the session.
   */
  startCollab(socket: CollabSocket, peer: Peer, room: string): CollabSession {
    // Namespace this client's generated ids so two peers never collide.
    this.controller.idPrefix = `${peer.id}-`;
    const session = new CollabSession(socket, peer, room, {
      onScene: (elements) => this.applyRemoteScene(elements),
      onRemoteElements: (elements) => this.applyRemoteElements(elements),
      onPresence: () => this.bump(),
    });
    this.collab = session;
    this.syncBroadcastBaseline();
    return session;
  }

  /** Stop collaborating (leaves the room and closes the socket). */
  stopCollab(): void {
    this.collab?.leave();
    this.collab = null;
  }

  /**
   * Subscribe to local edits — invoked after every mutation that bumps
   * `revision`. Returns an unsubscribe function. External collaboration adapters
   * (e.g. `@cyberdynecorp/excalidraw-yjs`) use this to mirror local edits into a
   * `Y.Doc`. Applying external elements via {@link applyExternalElements} does
   * **not** fire these listeners, so an adapter won't echo its own writes.
   */
  onChange(listener: () => void): () => void {
    this.changeListeners.add(listener);
    return () => this.changeListeners.delete(listener);
  }

  /**
   * Subscribe to local cursor moves (scene coordinates), fired from
   * {@link trackPointer}. External presence adapters publish these as the local
   * peer's cursor. Returns an unsubscribe function.
   */
  onCursorMove(listener: (scene: Point) => void): () => void {
    this.cursorListeners.add(listener);
    return () => this.cursorListeners.delete(listener);
  }

  /**
   * Replace the scene with elements merged by an external engine (e.g. a CRDT
   * adapter), without creating an undo step, without broadcasting on the LWW
   * collab transport, and without firing {@link onChange} (so it doesn't echo
   * back to the source). Bumps `revision` so the canvas redraws.
   */
  applyExternalElements(elements: ExcalidrawElement[]): void {
    this.controller.store.modifyScene((scene) => scene.replaceAll(elements));
    this.controller.store.rebase();
    this.revision += 1;
  }

  /** Remote peers' live cursors/selection, for presence rendering. */
  get remoteCursors(): RemoteCursor[] {
    return this.collab === null ? [] : [...this.collab.cursors.values()];
  }

  /**
   * Apply a room snapshot (on join / reconnect). The snapshot is *merged* with
   * the local scene by reconciliation rather than blindly replacing it, so edits
   * made while briefly disconnected survive — and anything the room doesn't yet
   * have (or that is locally newer) is re-broadcast after merging.
   */
  private applyRemoteScene(elements: ExcalidrawElement[]): void {
    const merged = reconcileElements(this.scene.elements, elements);
    this.controller.store.modifyScene((scene) => scene.replaceAll(merged));
    this.controller.store.rebase();
    // Treat only the room's versions as already-broadcast; local-only or
    // locally-newer elements stay "dirty" so broadcastLocalChanges re-publishes them.
    this.lastBroadcast.clear();
    for (const el of elements) this.lastBroadcast.set(el.id, el.version);
    this.revision += 1;
    this.broadcastLocalChanges();
  }

  /** Merge a versioned remote batch into the scene (reconciled, no undo step). */
  private applyRemoteElements(elements: ExcalidrawElement[]): void {
    const merged = reconcileElements(this.scene.elements, elements);
    this.controller.store.modifyScene((scene) => scene.replaceAll(merged));
    this.controller.store.rebase();
    this.syncBroadcastBaseline();
    this.revision += 1;
  }

  /** Mark every current element as already broadcast (call after applying remote). */
  private syncBroadcastBaseline(): void {
    this.lastBroadcast.clear();
    for (const el of this.scene.elements) this.lastBroadcast.set(el.id, el.version);
  }

  /** Send elements whose version changed since the last broadcast. */
  private broadcastLocalChanges(): void {
    if (this.collab === null) return;
    const changed: ExcalidrawElement[] = [];
    for (const el of this.scene.elements) {
      if (this.lastBroadcast.get(el.id) !== el.version) {
        changed.push(el);
        this.lastBroadcast.set(el.id, el.version);
      }
    }
    this.collab.broadcastElements(changed);
  }

  setEditingText(value: string): void {
    if (this.editingText === null) return;
    this.editingText = { ...this.editingText, value };
    this.bump(); // hosts derive editor chrome (e.g. centred padding) from the value
  }

  commitText(): void {
    if (this.editingText === null) return;
    const { id, value } = this.editingText;
    // A label created by this edit session that stays empty is removed whole
    // (text element + `boundElements` entry) instead of persisting as an
    // invisible empty label.
    if (value.length === 0 && id === this.pendingLabelID) {
      this.controller.removeBoundLabel(id);
    } else {
      this.controller.setText(id, value);
    }
    this.pendingLabelID = null;
    this.editingText = null;
    this.controller.setTool("selection");
    this.bump();
  }

  // MARK: Theme / zen

  setTheme(theme: Theme): void {
    this.theme = theme;
    this.bump();
  }
  toggleTheme(): void {
    this.setTheme(this.theme === "light" ? "dark" : "light");
  }
  toggleZen(): void {
    this.zenMode = !this.zenMode;
    this.bump();
  }

  // MARK: Render + documents

  render(
    ctx: RenderContext,
    width: number,
    height: number,
    images?: (fileId: string) => CanvasImageSource | null,
  ): void {
    this.canvasWidth = width;
    this.canvasHeight = height;
    renderScene(ctx, this.scene, {
      viewport: this.viewport,
      width,
      height,
      theme: this.theme,
      gridSize: this.gridEnabled ? 20 : undefined,
      images,
    });
  }

  /** Closed outline (scene coords) of the current suggested-binding target. */
  private suggestedOutline(): Point[] {
    const id = this.controller.suggestedBindingID;
    const el = id !== null ? this.scene.element(id) : undefined;
    if (el === undefined) return [];
    const cx = el.x + el.width / 2;
    const cy = el.y + el.height / 2;
    const center = new Point(cx, cy);
    // unrotatedOutline boxes ellipses; approximate the true curve instead.
    const base =
      el.type === "ellipse"
        ? Array.from({ length: 32 }, (_, i) => {
            const t = (i / 32) * 2 * Math.PI;
            return new Point(cx + (el.width / 2) * Math.cos(t), cy + (el.height / 2) * Math.sin(t));
          })
        : unrotatedOutline(el).points;
    return el.angle === 0 ? base : base.map((p) => p.rotated(center, el.angle));
  }

  /** Draw the interactive overlay (selection, handles, marquee, edit handles, trails). */
  renderOverlay(ctx: RenderContext, width: number, height: number, now = nowSeconds()): void {
    const c = this.controller;
    const handlesMap = c.transformHandles();
    const rotationHandle = handlesMap.get("rotation") ?? null;
    const handles = [...handlesMap].filter(([k]) => k !== "rotation").map(([, p]) => p);

    let linearPoints: Point[] = [];
    let linearMidpoints: Point[] = [];
    if (c.editingLinearID !== null) {
      const el = c.scene.element(c.editingLinearID);
      if (el?.type === "arrow" && el.elbowed) {
        linearMidpoints = c.elbowSegmentHandles(c.editingLinearID).map((h) => h.point);
      } else {
        const h = c.linearEditHandles();
        if (h !== null) {
          linearPoints = h.points;
          linearMidpoints = h.midpoints;
        }
      }
    }

    drawOverlay(ctx, {
      viewport: this.viewport,
      width,
      height,
      colors: this.overlayColors,
      suggestedOutline: this.suggestedOutline(),
      suggestedAnchors:
        c.suggestedBindingID !== null ? c.anchorPointsFor(c.suggestedBindingID) : [],
      selectionBounds: c.selectionBounds,
      handles,
      rotationHandle,
      selectionRect: c.selectionRect,
      snapLinesX: c.snapLinesX,
      snapLinesY: c.snapLinesY,
      linearPoints,
      linearMidpoints,
      cropFrame: c.cropFrame(),
      cropHandles: c.cropEditHandles() ?? [],
      now,
      laserDots: this.trail.visibleLaser(now),
      eraserDots: this.trail.visibleEraser(now),
      remoteCursors: [
        ...this.remoteCursors
          .filter((rc) => rc.pointer !== null)
          .map((rc) => ({
            color: rc.peer.color,
            name: rc.peer.name,
            x: rc.pointer!.x,
            y: rc.pointer!.y,
          })),
        ...this.externalCursors,
      ],
    });
  }

  exportSvg(): string {
    return exportSvg(this.scene);
  }

  documentJSON(): string {
    return SceneDocument.encode(this.scene);
  }

  loadDocument(json: string): void {
    this.controller.load(SceneDocument.decode(json));
    this.bump();
  }
}
