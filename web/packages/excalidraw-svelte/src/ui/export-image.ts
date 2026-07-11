import { commonBounds } from "../geometry/index.js";
import { Scene } from "../model/index.js";
import { Viewport, embedScene, exportSvg, renderScene } from "../render/index.js";
// Image export pipeline: rasterize the scene (or the selection) to a PNG via
// an offscreen canvas — optionally embedding the scene for round-trip — or
// produce an SVG string. The package renderer stays DOM-free; the canvas and
// bitmap loading live here in the host.
import type { EditorStore } from "../svelte/editor-store.js";

export interface ExportImageOptions {
  scale: 1 | 2 | 3;
  background: boolean;
  selectionOnly: boolean;
  embed: boolean;
}

const MARGIN = 16;

/** The scene to export: everything, or the selection plus its bound labels. */
function sceneFor(store: EditorStore, selectionOnly: boolean): Scene {
  if (!selectionOnly) return store.scene;
  const selected = store.controller.selectedElements;
  const ids = new Set(selected.map((e) => e.id));
  for (const el of selected) {
    for (const bound of el.boundElements ?? []) ids.add(bound.id);
  }
  return new Scene(store.scene.visibleElements.filter((e) => ids.has(e.id)));
}

/** Preload the bitmaps of every image element so the render pass is sync. */
async function imageResolver(
  store: EditorStore,
): Promise<(fileId: string) => CanvasImageSource | null> {
  const bitmaps = new Map<string, HTMLImageElement>();
  const loads: Promise<void>[] = [];
  for (const [id, file] of Object.entries(store.scene.files)) {
    const img = new Image();
    img.src = file.dataURL;
    bitmaps.set(id, img);
    loads.push(img.decode().catch(() => undefined));
  }
  await Promise.all(loads);
  return (fileId) => {
    const img = bitmaps.get(fileId);
    return img !== undefined && img.naturalWidth > 0 ? img : null;
  };
}

/** Rasterize to PNG bytes (null when there is nothing to export). */
export async function exportPngBytes(
  store: EditorStore,
  opts: ExportImageOptions,
): Promise<Uint8Array | null> {
  const scene = sceneFor(store, opts.selectionOnly);
  const box = commonBounds(scene.visibleElements);
  if (box === null) return null;
  const width = Math.max(1, Math.ceil((box.width + 2 * MARGIN) * opts.scale));
  const height = Math.max(1, Math.ceil((box.height + 2 * MARGIN) * opts.scale));
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (ctx === null) return null;

  const viewport = new Viewport(MARGIN - box.minX, MARGIN - box.minY, opts.scale);
  renderScene(ctx as unknown as Parameters<typeof renderScene>[0], scene, {
    viewport,
    width,
    height,
    theme: "light", // exports always use canonical colours
    background: opts.background ? undefined : "transparent",
    images: await imageResolver(store),
  });

  const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/png"));
  if (blob === null) return null;
  const bytes: Uint8Array = new Uint8Array(await blob.arrayBuffer());
  return opts.embed ? (embedScene(scene, bytes) ?? bytes) : bytes;
}

/** Produce the SVG export string (null when there is nothing to export). */
export function exportSvgString(
  store: EditorStore,
  opts: Pick<ExportImageOptions, "background" | "selectionOnly">,
): string | null {
  const scene = sceneFor(store, opts.selectionOnly);
  if (scene.visibleElements.length === 0) return null;
  return exportSvg(scene, MARGIN, opts.background ? undefined : "transparent");
}

/** Trigger a browser download for the given bytes/text. */
export function download(name: string, data: Uint8Array | string, type: string): void {
  const blob =
    typeof data === "string"
      ? new Blob([data], { type })
      : new Blob([data.buffer as ArrayBuffer], { type });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = name;
  a.click();
  URL.revokeObjectURL(a.href);
}
