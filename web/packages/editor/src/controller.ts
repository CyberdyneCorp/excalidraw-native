import {
  BoundingBox,
  DEFAULT_SNAP_DISTANCE,
  commonBounds,
  bounds as elementBounds,
  frameChildren,
  frameContaining,
  gapSnap,
  hit,
  isFrame,
  snap as objectSnap,
} from "@xs/geometry";
import { Point } from "@xs/math";
import { type ExcalidrawElement, type LocalPoint, RoundnessType, Scene, Store } from "@xs/model";
import { type CurrentItem, defaultCurrentItem, makeBase } from "./current-item.js";
import type { PointerEvent, PointerType } from "./pointer-event.js";
import { type Tool, toolElementType } from "./tool.js";
import { MIN_SIZE, Transform, type TransformHandle } from "./transform.js";

type Originals = Map<string, ExcalidrawElement>;

type Interaction =
  | { kind: "idle" }
  | { kind: "creating"; id: string; origin: Point; moved: boolean }
  | { kind: "freehand"; id: string; origin: Point }
  | { kind: "erasing" }
  | { kind: "moving"; origin: Point; originals: Originals }
  | { kind: "boxSelecting"; origin: Point }
  | { kind: "resizing"; handle: TransformHandle; bounds: BoundingBox; originals: Originals }
  | { kind: "rotating"; center: Point; originals: Originals };

export type ZOrder = "front" | "back" | "forward" | "backward";
export type Alignment = "left" | "centerX" | "right" | "top" | "centerY" | "bottom";

/**
 * The editing state machine: turns scene-space pointer events into element
 * creation, selection, move, resize, and rotation, with undo/redo. Pure TS (no
 * DOM). (parity: EditorController.swift)
 */
export class EditorController {
  store: Store;
  activeTool: Tool = "selection";
  toolLocked = false;
  currentItem: CurrentItem = defaultCurrentItem();
  zoom = 1;
  selectedIDs = new Set<string>();
  selectionRect: BoundingBox | null = null;
  snapEnabled = false;
  bindingEnabled = true;
  snapLinesX: number[] = [];
  snapLinesY: number[] = [];

  private interaction: Interaction = { kind: "idle" };
  private readonly nextID: () => string;
  private readonly nextSeed: () => number;

  constructor(scene: Scene = new Scene(), idProvider?: () => string, seedProvider?: () => number) {
    this.store = new Store(scene);
    let idCounter = 0;
    let seedCounter = 1;
    this.nextID = idProvider ?? (() => `el-${++idCounter}`);
    this.nextSeed = seedProvider ?? (() => ++seedCounter * 100_001);
  }

  get scene(): Scene {
    return this.store.scene;
  }
  get canUndo(): boolean {
    return this.store.canUndo;
  }
  get canRedo(): boolean {
    return this.store.canRedo;
  }
  get selectedElements(): ExcalidrawElement[] {
    return this.scene.visibleElements.filter((el) => this.selectedIDs.has(el.id));
  }
  get selectionBounds(): BoundingBox | null {
    return commonBounds(this.selectedElements);
  }
  get selectionOrContentBounds(): BoundingBox | null {
    return this.selectionBounds ?? commonBounds(this.scene.visibleElements);
  }

  /** Handle positions for the current selection (empty unless the selection tool is active). */
  transformHandles(): Map<TransformHandle, Point> {
    const bounds = this.selectionBounds;
    if (this.activeTool !== "selection" || bounds === null) return new Map();
    return Transform.handlePositions(bounds, this.rotationOffset);
  }

  // MARK: Pointer handling

  pointerDown(e: PointerEvent): void {
    this.selectionRect = null;
    if (this.activeTool === "eraser") {
      this.interaction = { kind: "erasing" };
      this.eraseAt(e.scenePoint);
      return;
    }
    if (this.activeTool === "hand") return;
    const type = toolElementType(this.activeTool);
    if (type !== null) this.beginCreating(type, e.scenePoint, e.pressure);
    else this.beginSelectionInteraction(e);
  }

  pointerMove(e: PointerEvent): void {
    const i = this.interaction;
    switch (i.kind) {
      case "creating":
        this.updateCreating(i.id, i.origin, e.scenePoint);
        this.interaction = { ...i, moved: true };
        break;
      case "freehand":
        this.appendFreehandPoint(i.id, i.origin, e.scenePoint, e.pressure);
        break;
      case "erasing":
        this.eraseAt(e.scenePoint);
        break;
      case "moving": {
        let dx = e.scenePoint.x - i.origin.x;
        let dy = e.scenePoint.y - i.origin.y;
        if (this.snapEnabled && !e.alt) {
          [dx, dy] = this.applyObjectSnap(i.originals, dx, dy);
        } else {
          this.snapLinesX = [];
          this.snapLinesY = [];
        }
        this.store.modifyScene((scene) => {
          for (const original of i.originals.values()) {
            scene.replace(Transform.translate(original, dx, dy));
          }
        });
        break;
      }
      case "boxSelecting":
        this.selectionRect = boxOf(i.origin, e.scenePoint);
        break;
      case "resizing": {
        const next = Transform.resize(i.bounds, i.handle, e.scenePoint, e.shift, e.alt);
        this.store.modifyScene((scene) => {
          for (const original of i.originals.values()) {
            scene.replace(Transform.scale(original, i.bounds, next));
          }
        });
        break;
      }
      case "rotating": {
        const angle = Transform.rotationAngle(i.center, e.scenePoint, e.shift);
        this.store.modifyScene((scene) => {
          for (const original of i.originals.values()) scene.replace({ ...original, angle });
        });
        break;
      }
      default:
        break;
    }
  }

  pointerUp(e: PointerEvent): void {
    const i = this.interaction;
    switch (i.kind) {
      case "creating":
        this.finishCreating(i.id, i.moved);
        break;
      case "freehand":
        this.finishFreehand();
        break;
      case "erasing":
        this.store.commit();
        this.selectedIDs = new Set();
        break;
      case "moving":
        this.snapLinesX = [];
        this.snapLinesY = [];
        this.reassignFrameMembership(new Set(i.originals.keys()));
        this.store.commit();
        break;
      case "resizing":
      case "rotating":
        this.snapLinesX = [];
        this.snapLinesY = [];
        this.store.commit();
        break;
      case "boxSelecting":
        this.selectWithin(boxOf(i.origin, e.scenePoint), e.toggleSelection);
        this.selectionRect = null;
        break;
      default:
        break;
    }
    this.interaction = { kind: "idle" };
  }

  // MARK: Commands

  load(scene: Scene): void {
    this.store = new Store(scene);
    this.selectedIDs = new Set();
    this.interaction = { kind: "idle" };
  }

  setTool(tool: Tool): void {
    this.activeTool = tool;
  }

  selectAll(): void {
    this.selectedIDs = new Set(this.scene.visibleElements.map((el) => el.id));
  }

  clearSelection(): void {
    this.selectedIDs = new Set();
  }

  deleteSelected(): void {
    if (this.selectedIDs.size === 0) return;
    this.store.transaction((scene) => {
      for (const id of this.selectedIDs) scene.remove(id);
    });
    this.selectedIDs = new Set();
  }

  /** Apply a change to every selected element as one undo step. */
  updateSelected(change: (draft: ExcalidrawElement) => void): void {
    if (this.selectedIDs.size === 0) return;
    this.store.transaction((scene) => {
      for (const id of this.selectedIDs) {
        const current = scene.element(id);
        if (current === undefined) continue;
        const draft = structuredClone(current);
        change(draft);
        scene.replace(draft);
      }
    });
  }

  undo(): boolean {
    const ok = this.store.undo();
    this.pruneSelection();
    return ok;
  }

  redo(): boolean {
    const ok = this.store.redo();
    this.pruneSelection();
    return ok;
  }

  // MARK: Actions (group / duplicate / align / flip / z-order / lock)

  group(): void {
    if (this.selectedIDs.size <= 1) return;
    const groupID = this.nextID();
    this.updateSelected((el) => {
      el.groupIds = [...el.groupIds, groupID];
    });
  }

  ungroup(): void {
    this.updateSelected((el) => {
      if (el.groupIds.length > 0) el.groupIds = el.groupIds.slice(0, -1);
    });
  }

  duplicate(): void {
    const originals = this.selectedElements;
    if (originals.length === 0) return;
    const newIDs: string[] = [];
    this.store.transaction((scene) => {
      for (const original of originals) {
        const copy = structuredClone(original);
        copy.id = this.nextID();
        copy.x += 10;
        copy.y += 10;
        scene.add(copy);
        newIDs.push(copy.id);
      }
    });
    this.selectedIDs = new Set(newIDs);
  }

  setLocked(locked: boolean): void {
    this.updateSelected((el) => {
      el.locked = locked;
    });
  }

  reorder(order: ZOrder): void {
    if (this.selectedIDs.size === 0) return;
    const selected = this.selectedIDs;
    this.store.transaction((scene) => {
      let elements = [...scene.elements];
      if (order === "front") {
        const moving = elements.filter((e) => selected.has(e.id));
        elements = elements.filter((e) => !selected.has(e.id));
        elements.push(...moving);
      } else if (order === "back") {
        const moving = elements.filter((e) => selected.has(e.id));
        elements = elements.filter((e) => !selected.has(e.id));
        elements.unshift(...moving);
      } else if (order === "forward") {
        for (let k = elements.length - 2; k >= 0; k--) {
          if (selected.has(elements[k]!.id) && !selected.has(elements[k + 1]!.id)) {
            [elements[k], elements[k + 1]] = [elements[k + 1]!, elements[k]!];
          }
        }
      } else {
        for (let k = 1; k < elements.length; k++) {
          if (selected.has(elements[k]!.id) && !selected.has(elements[k - 1]!.id)) {
            [elements[k], elements[k - 1]] = [elements[k - 1]!, elements[k]!];
          }
        }
      }
      scene.replaceAll(elements);
    });
  }

  align(alignment: Alignment): void {
    const group = this.selectionBounds;
    if (this.selectedElements.length <= 1 || group === null) return;
    this.updateSelected((el) => {
      const b = elementBounds(el);
      switch (alignment) {
        case "left":
          el.x += group.minX - b.minX;
          break;
        case "right":
          el.x += group.maxX - b.maxX;
          break;
        case "centerX":
          el.x += (group.minX + group.maxX) / 2 - (b.minX + b.maxX) / 2;
          break;
        case "top":
          el.y += group.minY - b.minY;
          break;
        case "bottom":
          el.y += group.maxY - b.maxY;
          break;
        case "centerY":
          el.y += (group.minY + group.maxY) / 2 - (b.minY + b.maxY) / 2;
          break;
      }
    });
  }

  flip(horizontal: boolean): void {
    const bounds = this.selectionBounds;
    if (bounds === null) return;
    this.updateSelected((el) => {
      const b = elementBounds(el);
      if (horizontal) el.x = bounds.minX + bounds.maxX - b.maxX;
      else el.y = bounds.minY + bounds.maxY - b.maxY;
      flipPoints(el, horizontal);
    });
  }

  // MARK: Interaction helpers

  private beginCreating(type: string, origin: Point, pressure: number): void {
    const base = makeBase(this.currentItem, this.nextID(), this.nextSeed(), origin.x, origin.y);
    let element: ExcalidrawElement;
    switch (type) {
      case "line":
        element = {
          ...base,
          type: "line",
          points: [
            [0, 0],
            [0, 0],
          ],
          startBinding: null,
          endBinding: null,
          startArrowhead: null,
          endArrowhead: null,
          polygon: false,
        };
        break;
      case "arrow":
        element = {
          ...base,
          type: "arrow",
          points: [
            [0, 0],
            [0, 0],
          ],
          startBinding: null,
          endBinding: null,
          startArrowhead: this.currentItem.startArrowhead,
          endArrowhead: this.currentItem.endArrowhead,
          elbowed: this.currentItem.elbowed,
        };
        break;
      case "freedraw": {
        const free: ExcalidrawElement = {
          ...base,
          type: "freedraw",
          points: [[0, 0]],
          pressures: [pressure],
          simulatePressure: false,
        };
        this.store.modifyScene((scene) => scene.add(free));
        this.selectedIDs = new Set([free.id]);
        this.interaction = { kind: "freehand", id: free.id, origin };
        return;
      }
      case "frame":
        element = { ...base, type: "frame", name: null };
        break;
      default:
        element = { ...base, type: type as "rectangle" | "diamond" | "ellipse" };
        break;
    }
    if (this.currentItem.roundEdges) {
      const roundness = roundnessType(type);
      if (roundness !== null) element.roundness = { type: roundness };
    }
    this.store.modifyScene((scene) => scene.add(element));
    this.selectedIDs = new Set([element.id]);
    this.interaction = { kind: "creating", id: element.id, origin, moved: false };
  }

  private updateCreating(id: string, origin: Point, point: Point): void {
    const el = this.scene.element(id);
    if (el === undefined) return;
    const endpoint: LocalPoint = [point.x - origin.x, point.y - origin.y];
    let updated: ExcalidrawElement;
    if (el.type === "line" || el.type === "arrow") {
      updated = {
        ...el,
        x: origin.x,
        y: origin.y,
        width: Math.abs(endpoint[0]),
        height: Math.abs(endpoint[1]),
        points: [[0, 0], endpoint],
      };
    } else {
      updated = {
        ...el,
        x: Math.min(origin.x, point.x),
        y: Math.min(origin.y, point.y),
        width: Math.abs(point.x - origin.x),
        height: Math.abs(point.y - origin.y),
      };
    }
    this.store.modifyScene((scene) => scene.replace(updated));
  }

  private finishCreating(id: string, moved: boolean): void {
    const el = this.scene.element(id);
    const tiny = (el?.width ?? 0) < MIN_SIZE && (el?.height ?? 0) < MIN_SIZE;
    if (!moved || tiny) {
      this.store.modifyScene((scene) =>
        scene.replaceAll(scene.elements.filter((e) => e.id !== id)),
      );
      this.selectedIDs = new Set();
    } else {
      this.reassignFrameMembership(new Set([id]));
      this.store.commit();
      if (!this.toolLocked) this.activeTool = "selection";
    }
  }

  private appendFreehandPoint(id: string, origin: Point, point: Point, pressure: number): void {
    const el = this.scene.element(id);
    if (el === undefined || el.type !== "freedraw") return;
    const points: LocalPoint[] = [...el.points, [point.x - origin.x, point.y - origin.y]];
    const xs = points.map((p) => p[0]);
    const ys = points.map((p) => p[1]);
    this.store.modifyScene((scene) =>
      scene.replace({
        ...el,
        points,
        pressures: [...el.pressures, pressure],
        width: Math.max(...xs) - Math.min(...xs),
        height: Math.max(...ys) - Math.min(...ys),
      }),
    );
  }

  private finishFreehand(): void {
    this.store.commit();
    if (!this.toolLocked) this.activeTool = "selection";
  }

  private applyObjectSnap(originals: Originals, dx: number, dy: number): [number, number] {
    const moved = [...originals.values()].map((el) => Transform.translate(el, dx, dy));
    const movingBounds = commonBounds(moved);
    if (movingBounds === null) {
      this.snapLinesX = [];
      this.snapLinesY = [];
      return [dx, dy];
    }
    const movingIDs = new Set(originals.keys());
    const statics = this.scene.visibleElements
      .filter((el) => !movingIDs.has(el.id))
      .map((el) => elementBounds(el));
    const threshold = DEFAULT_SNAP_DISTANCE / this.zoom;
    const result = objectSnap(movingBounds, statics, threshold);
    let offsetX = result.offsetX;
    let offsetY = result.offsetY;
    let linesX = result.verticalLines;
    let linesY = result.horizontalLines;

    const gap = gapSnap(movingBounds, statics, threshold);
    if (linesX.length === 0 && gap.verticalLines.length > 0) {
      offsetX = gap.offsetX;
      linesX = gap.verticalLines;
    }
    if (linesY.length === 0 && gap.horizontalLines.length > 0) {
      offsetY = gap.offsetY;
      linesY = gap.horizontalLines;
    }
    this.snapLinesX = linesX;
    this.snapLinesY = linesY;
    return [dx + offsetX, dy + offsetY];
  }

  private eraseAt(point: Point): void {
    const threshold = this.handleHitRadius("mouse");
    const hits = this.scene.visibleElements.filter((el) => !el.locked && hit(el, point, threshold));
    if (hits.length === 0) return;
    this.store.modifyScene((scene) => {
      for (const h of hits) scene.remove(h.id);
    });
  }

  private beginSelectionInteraction(e: PointerEvent): void {
    const point = e.scenePoint;
    const bounds = this.selectionBounds;
    if (bounds !== null) {
      for (const [handle, position] of Transform.handlePositions(bounds, this.rotationOffset)) {
        if (position.distance(point) <= this.handleHitRadius(e.type)) {
          const originals = this.snapshotSelected();
          this.interaction =
            handle === "rotation"
              ? {
                  kind: "rotating",
                  center: new Point(
                    (bounds.minX + bounds.maxX) / 2,
                    (bounds.minY + bounds.maxY) / 2,
                  ),
                  originals,
                }
              : { kind: "resizing", handle, bounds, originals };
          return;
        }
      }
    }

    const hitID = this.topElement(point, e.type);
    if (hitID !== null) {
      const group = this.groupSiblings(hitID);
      if (e.toggleSelection) {
        if (isSuperset(this.selectedIDs, group)) {
          for (const id of group) this.selectedIDs.delete(id);
        } else {
          for (const id of group) this.selectedIDs.add(id);
        }
      } else if (!this.selectedIDs.has(hitID)) {
        this.selectedIDs = new Set(group);
      }
      this.interaction = { kind: "moving", origin: point, originals: this.snapshotForMove() };
    } else {
      if (!e.toggleSelection) this.selectedIDs = new Set();
      this.interaction = { kind: "boxSelecting", origin: point };
      this.selectionRect = new BoundingBox(point.x, point.y, point.x, point.y);
    }
  }

  private snapshotSelected(): Originals {
    return new Map(this.selectedElements.map((el) => [el.id, el]));
  }

  private snapshotForMove(): Originals {
    const result = this.snapshotSelected();
    for (const el of this.selectedElements) {
      if (isFrame(el)) {
        for (const child of frameChildren(el.id, this.scene.visibleElements)) {
          result.set(child.id, child);
        }
      }
    }
    return result;
  }

  private reassignFrameMembership(ids: Set<string>): void {
    this.store.modifyScene((scene) => {
      for (const id of ids) {
        const el = scene.element(id);
        if (el === undefined || isFrame(el)) continue;
        const frameId = frameContaining(el, scene.visibleElements);
        if (el.frameId !== frameId) scene.replace({ ...el, frameId });
      }
    });
  }

  private topElement(point: Point, type: PointerType): string | null {
    const threshold = this.handleHitRadius(type);
    const visible = this.scene.visibleElements;
    for (let k = visible.length - 1; k >= 0; k--) {
      const el = visible[k]!;
      if (!el.locked && hit(el, point, threshold)) return el.id;
    }
    return null;
  }

  private selectWithin(rect: BoundingBox, additive: boolean): void {
    const within = this.scene.visibleElements
      .filter((el) => {
        const b = elementBounds(el);
        return (
          b.minX >= rect.minX && b.maxX <= rect.maxX && b.minY >= rect.minY && b.maxY <= rect.maxY
        );
      })
      .flatMap((el) => [...this.groupSiblings(el.id)]);
    if (additive) for (const id of within) this.selectedIDs.add(id);
    else this.selectedIDs = new Set(within);
  }

  groupSiblings(id: string): Set<string> {
    const el = this.scene.element(id);
    const group = el?.groupIds[el.groupIds.length - 1];
    if (el === undefined || group === undefined) return new Set([id]);
    const siblings = this.scene.visibleElements
      .filter((e) => e.groupIds.includes(group))
      .map((e) => e.id);
    return new Set([...siblings, id]);
  }

  private pruneSelection(): void {
    const live = new Set(this.scene.visibleElements.map((el) => el.id));
    this.selectedIDs = new Set([...this.selectedIDs].filter((id) => live.has(id)));
  }

  private handleHitRadius(type: PointerType): number {
    const px = type === "touch" ? 28 : type === "pen" ? 16 : 10;
    return px / this.zoom;
  }

  private get rotationOffset(): number {
    return 30 / this.zoom;
  }
}

function boxOf(a: Point, b: Point): BoundingBox {
  return new BoundingBox(
    Math.min(a.x, b.x),
    Math.min(a.y, b.y),
    Math.max(a.x, b.x),
    Math.max(a.y, b.y),
  );
}

function roundnessType(type: string): number | null {
  if (type === "line" || type === "arrow") return RoundnessType.proportionalRadius;
  if (type === "rectangle" || type === "diamond") return RoundnessType.adaptiveRadius;
  return null;
}

function isSuperset(set: Set<string>, subset: Set<string>): boolean {
  for (const id of subset) if (!set.has(id)) return false;
  return true;
}

function flipPoints(el: ExcalidrawElement, horizontal: boolean): void {
  if (el.type !== "line" && el.type !== "arrow" && el.type !== "freedraw") return;
  const xs = el.points.map((p) => p[0]);
  const ys = el.points.map((p) => p[1]);
  const maxX = Math.max(...xs);
  const maxY = Math.max(...ys);
  el.points = el.points.map((p) => [
    horizontal ? maxX - p[0] : p[0],
    horizontal ? p[1] : maxY - p[1],
  ]);
}
