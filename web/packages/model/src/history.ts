import type { ExcalidrawElement } from "./element.js";
import { semanticEqual } from "./json.js";
import type { Scene } from "./scene.js";

/**
 * The change to a single element between two scene states. A `null` side means
 * the element was absent (insertion when `before === null`, removal when
 * `after === null`). (parity: History.swift)
 */
export interface ElementChange {
  before: ExcalidrawElement | null;
  after: ExcalidrawElement | null;
}

function byId(list: ExcalidrawElement[]): Map<string, ExcalidrawElement> {
  const map = new Map<string, ExcalidrawElement>();
  for (const el of list) map.set(el.id, el);
  return map;
}

/** A reversible diff between two element lists, keyed by element id. */
export class SceneDelta {
  constructor(public changes: Map<string, ElementChange> = new Map()) {}

  get isEmpty(): boolean {
    return this.changes.size === 0;
  }

  /** Diff `old` → `next`, recording only elements that actually changed. */
  static between(oldList: ExcalidrawElement[], nextList: ExcalidrawElement[]): SceneDelta {
    const oldById = byId(oldList);
    const newById = byId(nextList);
    const changes = new Map<string, ElementChange>();
    for (const id of new Set([...oldById.keys(), ...newById.keys()])) {
      const before = oldById.get(id) ?? null;
      const after = newById.get(id) ?? null;
      if (!semanticEqual(before, after)) changes.set(id, { before, after });
    }
    return new SceneDelta(changes);
  }

  /** The delta that undoes this one (`before` and `after` swapped). */
  inverse(): SceneDelta {
    const inverted = new Map<string, ElementChange>();
    for (const [id, change] of this.changes) {
      inverted.set(id, { before: change.after, after: change.before });
    }
    return new SceneDelta(inverted);
  }
}

/** Undo/redo stacks of recorded deltas. */
export class History {
  private undoStack: SceneDelta[] = [];
  private redoStack: SceneDelta[] = [];

  get canUndo(): boolean {
    return this.undoStack.length > 0;
  }

  get canRedo(): boolean {
    return this.redoStack.length > 0;
  }

  /** Record a new change, clearing the redo stack (a fresh edit branches history). */
  record(delta: SceneDelta): void {
    if (delta.isEmpty) return;
    this.undoStack.push(delta);
    this.redoStack = [];
  }

  popUndo(): SceneDelta | null {
    const delta = this.undoStack.pop();
    if (delta === undefined) return null;
    this.redoStack.push(delta);
    return delta;
  }

  popRedo(): SceneDelta | null {
    const delta = this.redoStack.pop();
    if (delta === undefined) return null;
    this.undoStack.push(delta);
    return delta;
  }
}

/**
 * Ties a `Scene` to a `History`: capture edits, then undo/redo them. Mutate the
 * scene via `store.scene`, then `commit()` to snapshot the change.
 */
export class Store {
  private history = new History();
  private snapshot: ExcalidrawElement[];

  constructor(public scene: Scene) {
    this.snapshot = scene.elements;
  }

  get canUndo(): boolean {
    return this.history.canUndo;
  }

  get canRedo(): boolean {
    return this.history.canRedo;
  }

  /** Mutate the scene in a callback and capture the change as one undo step. */
  transaction(body: (scene: Scene) => void): void {
    body(this.scene);
    this.commit();
  }

  /** Mutate the working scene without recording history (live interaction). */
  modifyScene(body: (scene: Scene) => void): void {
    body(this.scene);
  }

  /**
   * Advance the undo baseline to the current scene *without* recording a step —
   * used after applying a remote collaborative update so it doesn't fold into
   * the local user's next undo.
   */
  rebase(): void {
    this.snapshot = this.scene.elements;
  }

  /** Capture changes since the last commit as one undo step. */
  commit(): void {
    const delta = SceneDelta.between(this.snapshot, this.scene.elements);
    if (delta.isEmpty) return;
    this.history.record(delta);
    this.snapshot = this.scene.elements;
  }

  undo(): boolean {
    const delta = this.history.popUndo();
    if (delta === null) return false;
    this.scene.apply(delta.inverse());
    this.snapshot = this.scene.elements;
    return true;
  }

  redo(): boolean {
    const delta = this.history.popRedo();
    if (delta === null) return false;
    this.scene.apply(delta);
    this.snapshot = this.scene.elements;
    return true;
  }
}
