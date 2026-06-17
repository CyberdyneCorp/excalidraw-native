import type { ExcalidrawElement } from "./element.js";
import type { ExcalidrawFile } from "./file.js";
import { makeFile } from "./file.js";
import type { SceneDelta } from "./history.js";
import type { AppState, BinaryFileData } from "./value-types.js";

/**
 * In-memory editing model: the ordered element list plus the document's app
 * state and file store. Elements are treated immutably — every mutation
 * produces a new `elements` array and replaces (never mutates) element objects,
 * so history snapshots that hold the previous array stay valid. (parity:
 * Scene.swift)
 */
export class Scene {
  private elementList: ExcalidrawElement[];
  private indexById: Map<string, number>;

  appState: AppState;
  files: Record<string, BinaryFileData>;

  constructor(
    elements: ExcalidrawElement[] = [],
    appState: AppState = {},
    files: Record<string, BinaryFileData> = {},
  ) {
    this.elementList = elements;
    this.appState = appState;
    this.files = files;
    this.indexById = Scene.buildIndex(elements);
  }

  static fromFile(file: ExcalidrawFile): Scene {
    return new Scene(file.elements, file.appState, file.files);
  }

  toFile(source = "excalidraw-web"): ExcalidrawFile {
    return makeFile({
      source,
      elements: this.elementList,
      appState: this.appState,
      files: this.files,
    });
  }

  get elements(): ExcalidrawElement[] {
    return this.elementList;
  }

  element(id: string): ExcalidrawElement | undefined {
    const i = this.indexById.get(id);
    return i === undefined ? undefined : this.elementList[i];
  }

  /** Non-deleted elements in document order. */
  get visibleElements(): ExcalidrawElement[] {
    return this.elementList.filter((el) => !el.isDeleted);
  }

  add(element: ExcalidrawElement): void {
    this.indexById = new Map(this.indexById);
    this.indexById.set(element.id, this.elementList.length);
    this.elementList = [...this.elementList, element];
  }

  /**
   * Apply a change to an element and bump its version (`version`,
   * `versionNonce`, `updated`) so it reconciles like an upstream edit. The
   * callback receives a fresh clone to mutate.
   */
  mutate(
    id: string,
    mutator: (draft: ExcalidrawElement) => void,
    options: { timestamp?: number; versionNonce?: number } = {},
  ): boolean {
    const i = this.indexById.get(id);
    if (i === undefined) return false;
    const draft = structuredClone(this.elementList[i]!);
    mutator(draft);
    draft.version += 1;
    if (options.versionNonce !== undefined) draft.versionNonce = options.versionNonce;
    if (options.timestamp !== undefined) draft.updated = options.timestamp;
    const next = [...this.elementList];
    next[i] = draft;
    this.elementList = next;
    return true;
  }

  /** Replace the entire ordered element list (e.g. after a z-order change). */
  replaceAll(elements: ExcalidrawElement[]): void {
    this.elementList = elements;
    this.indexById = Scene.buildIndex(elements);
  }

  /** Replace an element in place by id, without bumping its version. */
  replace(element: ExcalidrawElement): boolean {
    const i = this.indexById.get(element.id);
    if (i === undefined) return false;
    const next = [...this.elementList];
    next[i] = element;
    this.elementList = next;
    return true;
  }

  /** Soft-delete (Excalidraw keeps deleted elements for history/collab). */
  remove(id: string, timestamp?: number): boolean {
    return this.mutate(
      id,
      (el) => {
        el.isDeleted = true;
      },
      timestamp === undefined ? {} : { timestamp },
    );
  }

  /** Apply a `SceneDelta`, preserving element order. */
  apply(delta: SceneDelta): void {
    if (delta.isEmpty) return;
    const byId = new Map(this.elementList.map((el) => [el.id, el] as const));
    const order = this.elementList.map((el) => el.id);
    for (const [id, change] of delta.changes) {
      if (change.after !== null) {
        if (!byId.has(id)) order.push(id);
        byId.set(id, change.after);
      } else {
        byId.delete(id);
        const at = order.indexOf(id);
        if (at !== -1) order.splice(at, 1);
      }
    }
    const next: ExcalidrawElement[] = [];
    for (const id of order) {
      const el = byId.get(id);
      if (el !== undefined) next.push(el);
    }
    this.replaceAll(next);
  }

  private static buildIndex(elements: ExcalidrawElement[]): Map<string, number> {
    const map = new Map<string, number>();
    elements.forEach((el, i) => map.set(el.id, i));
    return map;
  }
}
