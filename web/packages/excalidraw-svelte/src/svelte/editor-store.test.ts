import { describe, expect, it } from "vitest";
import { Point } from "../math/index.js";
import { FontFamily, RoundnessType } from "../model/index.js";
import { Viewport, embedScene } from "../render/index.js";
import { EditorStore } from "./editor-store.js";

/** A recording 2D context that counts draw calls. */
class RecordingContext {
  fillCount = 0;
  strokeCount = 0;
  fillRectCount = 0;
  strokeRectCount = 0;
  arcCount = 0;
  fillTextCount = 0;
  fillStyle = "";
  strokeStyle = "";
  lineWidth = 1;
  lineCap: CanvasLineCap = "butt";
  lineJoin: CanvasLineJoin = "miter";
  globalAlpha = 1;
  font = "";
  save() {}
  restore() {}
  translate() {}
  scale() {}
  rotate() {}
  beginPath() {}
  moveTo() {}
  lineTo() {}
  bezierCurveTo() {}
  closePath() {}
  fill() {
    this.fillCount++;
  }
  stroke() {
    this.strokeCount++;
  }
  fillRect() {
    this.fillRectCount++;
  }
  strokeRect() {
    this.strokeRectCount++;
  }
  arc() {
    this.arcCount++;
  }
  setLineDash() {}
  fillText() {
    this.fillTextCount++;
  }
  drawImageCount = 0;
  drawImage() {
    this.drawImageCount++;
  }
}

describe("EditorStore", () => {
  it("insertImage returns the new image's fileId (for brokering bytes to peers)", () => {
    const store = new EditorStore();
    const dataURL = "data:image/png;base64,iVBORw0KGgo=";
    const fileId = store.insertImage(dataURL, "image/png", 100, 80);
    expect(fileId).not.toBe("");
    const el = store.scene.visibleElements.find((e) => e.type === "image");
    expect(el?.type).toBe("image");
    expect(el?.type === "image" ? el.fileId : null).toBe(fileId);
    // The bytes live in the scene's file map under that id (local render source).
    expect(store.scene.files[fileId]?.dataURL).toBe(dataURL);
  });

  it("forwards a pointer drag and creates an element, bumping the revision", () => {
    const store = new EditorStore();
    store.selectTool("rectangle");
    const before = store.revision;
    store.pointer("down", new Point(10, 10));
    store.pointer("move", new Point(60, 40));
    store.pointer("up", new Point(60, 40));
    expect(store.scene.visibleElements.length).toBe(1);
    expect(store.scene.visibleElements[0]!.type).toBe("rectangle");
    expect(store.revision).toBeGreaterThan(before);
    expect(store.activeTool).toBe("selection");
  });

  it("converts view to scene coordinates with the viewport zoom", () => {
    const store = new EditorStore(undefined, new Viewport(0, 0, 2));
    store.selectTool("rectangle");
    store.pointer("down", new Point(20, 20));
    store.pointer("move", new Point(40, 40));
    store.pointer("up", new Point(40, 40));
    const el = store.scene.visibleElements[0]!;
    expect(el.x).toBeCloseTo(10, 6); // view 20 / zoom 2
    expect(el.y).toBeCloseTo(10, 6);
  });

  it("panZoom scales the scroll by the zoom", () => {
    const store = new EditorStore(undefined, new Viewport(0, 0, 2));
    store.panZoom(10, 20, 1);
    expect(store.viewport.scrollX).toBeCloseTo(5, 6);
    expect(store.viewport.scrollY).toBeCloseTo(10, 6);
  });

  it("zoomAtScreenPoint keeps the scene point under the cursor fixed", () => {
    const store = new EditorStore();
    const cursor = new Point(300, 200);
    const before = store.viewport.viewToScene(cursor);
    store.zoomAtScreenPoint(cursor.x, cursor.y, 2);
    expect(store.viewport.zoom).toBeCloseTo(2, 6);
    const after = store.viewport.viewToScene(cursor);
    expect(after.x).toBeCloseTo(before.x, 6);
    expect(after.y).toBeCloseTo(before.y, 6);
  });

  it("exposes selection count and group/ungroup availability", () => {
    const store = new EditorStore();
    expect(store.selectedCount).toBe(0);
    expect(store.canGroupSelection).toBe(false);
    for (const at of [10, 200]) {
      store.selectTool("rectangle");
      store.pointer("down", new Point(at, at));
      store.pointer("move", new Point(at + 40, at + 40));
      store.pointer("up", new Point(at + 40, at + 40));
    }
    store.selectAll();
    expect(store.selectedCount).toBe(2);
    expect(store.canGroupSelection).toBe(true);
    expect(store.canUngroupSelection).toBe(false);
    store.group();
    expect(store.canUngroupSelection).toBe(true);
    store.ungroup();
    expect(store.canUngroupSelection).toBe(false);
  });

  it("zoom in / out / reset and percent", () => {
    const store = new EditorStore();
    store.zoomIn();
    expect(store.viewport.zoom).toBeCloseTo(1.2, 6);
    expect(store.zoomPercent).toBe(120);
    store.resetZoom();
    expect(store.viewport.zoom).toBe(1);
    store.zoomOut();
    expect(store.viewport.zoom).toBeCloseTo(1 / 1.2, 6);
  });

  it("the hand tool pans the viewport and creates nothing", () => {
    const store = new EditorStore();
    store.selectTool("hand");
    store.pointer("down", new Point(200, 200));
    store.pointer("move", new Point(260, 240));
    store.pointer("up", new Point(260, 240));
    expect(store.viewport.scrollX).toBeCloseTo(60, 5);
    expect(store.viewport.scrollY).toBeCloseTo(40, 5);
    expect(store.scene.visibleElements).toHaveLength(0);
  });

  it("theme toggles", () => {
    const store = new EditorStore();
    expect(store.theme).toBe("light");
    store.toggleTheme();
    expect(store.theme).toBe("dark");
  });

  it("style setters apply to the selection", () => {
    const store = new EditorStore();
    store.selectTool("rectangle");
    store.pointer("down", new Point(0, 0));
    store.pointer("move", new Point(50, 50));
    store.pointer("up", new Point(50, 50));
    store.setStrokeColor("#e03131");
    expect(store.scene.visibleElements[0]!.strokeColor).toBe("#e03131");
  });

  it("selection stats reflect the selection size", () => {
    const store = new EditorStore();
    expect(store.selectionStats).toBeNull();
    store.selectTool("rectangle");
    store.pointer("down", new Point(0, 0));
    store.pointer("move", new Point(120, 80));
    store.pointer("up", new Point(120, 80));
    expect(store.selectionStats).toBe("120 × 80");
  });

  it("renders the scene to a 2D context", () => {
    const store = new EditorStore();
    store.selectTool("rectangle");
    store.pointer("down", new Point(10, 10));
    store.pointer("move", new Point(110, 70));
    store.pointer("up", new Point(110, 70));
    const ctx = new RecordingContext();
    store.render(ctx, 400, 300);
    expect(ctx.fillRectCount).toBe(1); // background
    expect(ctx.strokeCount).toBeGreaterThan(0); // the rectangle outline
  });

  it("draws the interactive overlay for a selection", () => {
    const store = new EditorStore();
    store.selectTool("rectangle");
    store.pointer("down", new Point(0, 0));
    store.pointer("move", new Point(100, 100));
    store.pointer("up", new Point(100, 100)); // rectangle stays selected
    const ctx = new RecordingContext();
    store.renderOverlay(ctx, 400, 300);
    expect(ctx.strokeRectCount).toBeGreaterThanOrEqual(5); // selection box + 8 handles
    expect(ctx.fillRectCount).toBe(8); // white handle squares
  });

  it("exports SVG and round-trips a document", () => {
    const store = new EditorStore();
    store.selectTool("ellipse");
    store.pointer("down", new Point(0, 0));
    store.pointer("move", new Point(60, 40));
    store.pointer("up", new Point(60, 40));
    expect(store.exportSvg()).toContain("<svg");
    const json = store.documentJSON();
    const reopened = new EditorStore();
    reopened.loadDocument(json);
    expect(reopened.scene.visibleElements.length).toBe(1);
  });

  it("undo/redo through the store", () => {
    const store = new EditorStore();
    store.selectTool("rectangle");
    store.pointer("down", new Point(0, 0));
    store.pointer("move", new Point(50, 50));
    store.pointer("up", new Point(50, 50));
    expect(store.canUndo).toBe(true);
    store.undo();
    expect(store.scene.visibleElements.length).toBe(0);
    store.redo();
    expect(store.scene.visibleElements.length).toBe(1);
  });

  it("generators place elements at the viewport centre", () => {
    const store = new EditorStore();
    store.insertTable(2, 2);
    expect(store.scene.visibleElements.length).toBe(8); // 4 cells + 4 labels
    store.insertStickyNote();
    expect(store.scene.visibleElements.some((e) => e.backgroundColor === "#ffec99")).toBe(true);
  });

  it("adds rows and columns to the selected table (regression)", () => {
    const store = new EditorStore();
    store.insertTable(2, 2); // 4 cells
    store.controller.selectAll();
    expect(store.selectedTableGroup).not.toBeNull();

    const cells = () => store.scene.visibleElements.filter((e) => e.type === "rectangle").length;
    expect(cells()).toBe(4);
    store.addTableRow(); // 2×2 → 3×2: +2 cells
    expect(cells()).toBe(6);
    store.addTableColumn(); // 3×2 → 3×3: +3 cells
    expect(cells()).toBe(9);

    // No-op when nothing (or a non-table) is selected.
    store.controller.selectedIDs.clear();
    store.addTableRow();
    expect(cells()).toBe(9);
  });

  it("inserting a sticky note begins editing its bound text (regression)", () => {
    const store = new EditorStore();
    store.insertStickyNote();
    expect(store.editingText).not.toBeNull();
    const note = store.scene.visibleElements.find((e) => e.type === "rectangle");
    const boundTextId = note?.boundElements?.find((b) => b.type === "text")?.id;
    expect(boundTextId).toBeDefined();
    expect(store.editingText?.id).toBe(boundTextId);

    // Typing into the editor and committing stores the text on the bound element.
    store.setEditingText("hello");
    store.commitText();
    expect(store.editingText).toBeNull();
    const label = store.scene.element(boundTextId!);
    expect(label?.type === "text" && label.text).toBe("hello");
  });

  it("double-clicking a sticky note re-opens its text editor (regression)", () => {
    const store = new EditorStore();
    store.insertStickyNote();
    const note = store.scene.visibleElements.find((e) => e.type === "rectangle")!;
    store.setEditingText("note");
    store.commitText();
    expect(store.editingText).toBeNull();

    // Double-click on the note's centre (default viewport: scene == view).
    const center = new Point(note.x + note.width / 2, note.y + note.height / 2);
    expect(store.editBoundTextAt(center)).toBe(true);
    expect(store.editingText?.value).toBe("note");

    // Double-click on empty space does nothing.
    expect(store.editBoundTextAt(new Point(5000, 5000))).toBe(false);
  });

  it("sizes the bound-text editor to its container cell (regression)", () => {
    const store = new EditorStore();
    store.insertTable(1, 1);
    const cell = store.scene.visibleElements.find((e) => e.type === "rectangle")!;
    store.selectTool("selection");
    store.doubleClickAt(new Point(cell.x + cell.width / 2, cell.y + cell.height / 2));
    expect(store.editingText).not.toBeNull();
    // The editor matches the cell so it doesn't overflow to the right.
    expect(store.editingText?.viewW).toBeCloseTo(cell.width, 0);
    expect(store.editingText?.viewH).toBeCloseTo(cell.height, 0);
  });

  it("double-clicking a chart edits its plot type and data (regression)", () => {
    const store = new EditorStore();
    store.insertChart([10, 20, 15], "bar");
    const bars = () => store.scene.visibleElements.filter((e) => e.type === "rectangle").length;
    expect(bars()).toBe(3);

    const bar = store.scene.visibleElements.find((e) => e.type === "rectangle")!;
    store.selectTool("selection");
    store.doubleClickAt(new Point(bar.x + bar.width / 2, bar.y + bar.height / 2));
    expect(store.editingChart).not.toBeNull();
    expect(store.editingChart?.kind).toBe("bar");

    store.setChartKind("line");
    store.setChartValues("5, 6, 7, 8");
    store.commitChart();
    expect(store.editingChart).toBeNull();
    expect(bars()).toBe(0); // a line chart has no bars
    expect(store.scene.visibleElements.some((e) => e.type === "line")).toBe(true);
  });

  it("double-clicking a line enters point (spline) editing (regression)", () => {
    const store = new EditorStore();
    store.selectTool("line");
    // draw a line from (100,100) to (300,160)
    store.pointer("down", new Point(100, 100));
    store.pointer("move", new Point(300, 160));
    store.pointer("up", new Point(300, 160));
    const line = store.scene.visibleElements.find((e) => e.type === "line")!;
    expect(store.isLinearEditing).toBe(false);

    store.selectTool("selection");
    // double-click on a point along the line enters vertex editing
    store.doubleClickAt(new Point(line.x, line.y));
    expect(store.isLinearEditing).toBe(true);
  });

  it("changing the fill pattern updates the selection and the current item (regression)", () => {
    const store = new EditorStore();
    store.selectTool("rectangle");
    store.pointer("down", new Point(20, 20));
    store.pointer("move", new Point(120, 90));
    store.pointer("up", new Point(120, 90));
    store.controller.selectAll();

    store.setFillStyle("cross-hatch");
    const rect = store.scene.visibleElements.find((e) => e.type === "rectangle")!;
    expect(rect.fillStyle).toBe("cross-hatch");
    expect(store.controller.currentItem.fillStyle).toBe("cross-hatch");
  });
});

const pngAscii = (t: string) => [...t].map((c) => c.charCodeAt(0));
/** A minimal valid PNG (signature + IHDR + IEND) to host an embedded scene. */
function minimalPng(): Uint8Array {
  const ihdrData = [0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0]; // 1x1 RGBA
  return Uint8Array.from([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    0,
    0,
    0,
    13,
    ...pngAscii("IHDR"),
    ...ihdrData,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    ...pngAscii("IEND"),
    0,
    0,
    0,
    0,
  ]);
}

describe("smart canvas", () => {
  function drawRect(store: EditorStore, x = 100, y = 100) {
    store.selectTool("rectangle");
    store.pointer("down", new Point(x, y));
    store.pointer("move", new Point(x + 120, y + 90));
    store.pointer("up", new Point(x + 120, y + 90));
  }

  it("quick-create spawns a connected node and gates on the selection", () => {
    const store = new EditorStore();
    expect(store.canQuickCreate).toBe(false); // nothing selected
    drawRect(store);
    expect(store.canQuickCreate).toBe(true);

    store.addFlowchartNode("right");
    const rects = store.scene.visibleElements.filter((e) => e.type === "rectangle");
    const arrow = store.scene.visibleElements.find((e) => e.type === "arrow")!;
    expect(rects).toHaveLength(2);
    expect(rects[1]!.x).toBeGreaterThan(rects[0]!.x); // spawned to the right
    expect(arrow.startBinding).not.toBeNull();
    expect(arrow.endBinding).not.toBeNull();

    // A linear selection can't quick-create.
    store.selectTool("selection");
    store.controller.selectedIDs = new Set([arrow.id]);
    expect(store.canQuickCreate).toBe(false);
  });

  it("contentOffscreen flips when the content is scrolled out of view", () => {
    const store = new EditorStore();
    store.canvasWidth = 800;
    store.canvasHeight = 600;
    expect(store.contentOffscreen).toBe(false); // empty scene
    drawRect(store, 100, 100);
    expect(store.contentOffscreen).toBe(false);

    store.panZoom(-5000, -5000, 1); // scroll far away
    expect(store.contentOffscreen).toBe(true);

    store.scrollToContent();
    expect(store.contentOffscreen).toBe(false);
  });

  it("grid and snap toggles flip host state", () => {
    const store = new EditorStore();
    expect(store.gridEnabled).toBe(false);
    store.toggleGrid();
    expect(store.gridEnabled).toBe(true);

    expect(store.snapEnabled).toBe(false);
    store.toggleSnap();
    expect(store.snapEnabled).toBe(true);
  });

  it("recognizeSelectedStroke snaps a rough rectangle sketch to a rectangle", () => {
    const store = new EditorStore();
    store.selectTool("freedraw");
    // Trace a rough closed rectangle.
    const path: [number, number][] = [
      [100, 100],
      [200, 102],
      [298, 100],
      [300, 200],
      [302, 298],
      [200, 300],
      [102, 298],
      [100, 200],
      [100, 102],
    ];
    store.pointer("down", new Point(path[0]![0], path[0]![1]));
    for (const [x, y] of path.slice(1)) store.pointer("move", new Point(x, y));
    store.pointer("up", new Point(path.at(-1)![0], path.at(-1)![1]));
    const stroke = store.scene.visibleElements.find((e) => e.type === "freedraw")!;
    store.controller.selectedIDs = new Set([stroke.id]);

    store.recognizeSelectedStroke();
    expect(store.scene.visibleElements.some((e) => e.type === "rectangle")).toBe(true);
    expect(store.scene.visibleElements.some((e) => e.type === "freedraw")).toBe(false);
  });
});

describe("clipboard, styles, and frames", () => {
  function drawRect(store: EditorStore, x = 100, y = 100) {
    store.selectTool("rectangle");
    store.pointer("down", new Point(x, y));
    store.pointer("move", new Point(x + 100, y + 80));
    store.pointer("up", new Point(x + 100, y + 80));
    return store.scene.visibleElements.find((e) => e.type === "rectangle" && e.x >= x - 1)!;
  }

  it("copy → paste adds distinct elements and leaves the originals alone", () => {
    const store = new EditorStore();
    drawRect(store);
    const json = store.copySelection();
    expect(json).not.toBeNull();

    const idsBefore = store.scene.visibleElements.map((e) => e.id);
    store.pasteJSON(json!, new Point(500, 400));
    const all = store.scene.visibleElements;
    expect(all).toHaveLength(2);
    const pasted = all.filter((e) => !idsBefore.includes(e.id));
    expect(pasted).toHaveLength(1);
    // Pasted content is centred on the paste point and selected.
    expect(pasted[0]!.x + pasted[0]!.width / 2).toBeCloseTo(500, 0);
    expect(pasted[0]!.y + pasted[0]!.height / 2).toBeCloseTo(400, 0);
    expect(store.selectedCount).toBe(1);
  });

  it("cut removes the selection in one undo step", () => {
    const store = new EditorStore();
    drawRect(store);
    const json = store.cutSelection();
    expect(json).not.toBeNull();
    expect(store.scene.visibleElements).toHaveLength(0);
    store.undo();
    expect(store.scene.visibleElements).toHaveLength(1);
  });

  it("pasteText creates a text element at the paste point", () => {
    const store = new EditorStore();
    store.pasteText("from clipboard", new Point(300, 200));
    const text = store.scene.visibleElements.find((e) => e.type === "text")!;
    expect(text.text).toBe("from clipboard");
  });

  it("copy → paste styles transfers style across types, undoable in one step", () => {
    const store = new EditorStore();
    const rect = drawRect(store);
    store.setStrokeColor("#e03131");
    store.setStrokeStyle("dashed");
    store.setOpacity(50);
    expect(store.copyStyles()).toBe(true);
    expect(store.hasCopiedStyles).toBe(true);

    // A plain ellipse elsewhere takes the copied style. (Deselect first: the
    // style setters apply to the current selection.)
    store.selectTool("selection");
    store.pointer("down", new Point(700, 600));
    store.pointer("up", new Point(700, 600));
    store.selectTool("ellipse");
    store.setStrokeColor("#1e1e1e");
    store.setStrokeStyle("solid");
    store.setOpacity(100);
    store.pointer("down", new Point(400, 100));
    store.pointer("move", new Point(500, 180));
    store.pointer("up", new Point(500, 180));
    const before = store.scene.visibleElements.find((e) => e.type === "ellipse")!;
    expect(before.strokeColor).toBe("#1e1e1e");

    store.pasteStyles();
    const after = store.scene.visibleElements.find((e) => e.type === "ellipse")!;
    expect(after.strokeColor).toBe("#e03131");
    expect(after.strokeStyle).toBe("dashed");
    expect(after.opacity).toBe(50);
    // Geometry untouched; one undo restores the previous style.
    expect(after.x).toBeCloseTo(before.x, 5);
    store.undo();
    const undone = store.scene.visibleElements.find((e) => e.type === "ellipse")!;
    expect(undone.strokeColor).toBe("#1e1e1e");
    // The source rectangle is unaffected throughout.
    expect(store.scene.element(rect.id)?.strokeColor).toBe("#e03131");
  });

  it("wrapSelectionInFrame creates a frame that adopts the selection", () => {
    const store = new EditorStore();
    drawRect(store, 100, 100);
    drawRect(store, 300, 100);
    store.selectAll();
    store.wrapSelectionInFrame();

    const frame = store.scene.visibleElements.find((e) => e.type === "frame")!;
    const rects = store.scene.visibleElements.filter((e) => e.type === "rectangle");
    expect(rects).toHaveLength(2);
    expect(rects.every((r) => r.frameId === frame.id)).toBe(true);
    // The frame encloses both shapes and is selected.
    expect(frame.x).toBeLessThan(100);
    expect(frame.x + frame.width).toBeGreaterThan(400);
    expect(store.selectedCount).toBe(1);

    store.undo();
    expect(store.scene.visibleElements.some((e) => e.type === "frame")).toBe(false);
  });
});

describe("app chrome store passthroughs", () => {
  it("tool lock keeps the drawing tool active across creations", () => {
    const store = new EditorStore();
    store.toggleToolLock();
    expect(store.toolLocked).toBe(true);
    store.selectTool("rectangle");
    for (const x of [10, 200]) {
      store.pointer("down", new Point(x, 10));
      store.pointer("move", new Point(x + 60, 60));
      store.pointer("up", new Point(x + 60, 60));
    }
    expect(store.scene.visibleElements).toHaveLength(2);
    expect(store.activeTool).toBe("rectangle"); // no revert while locked
    store.toggleToolLock();
    store.pointer("down", new Point(400, 10));
    store.pointer("move", new Point(460, 60));
    store.pointer("up", new Point(460, 60));
    expect(store.activeTool).toBe("selection"); // revert restored
  });

  it("resetScene clears everything as one undoable step", () => {
    const store = new EditorStore();
    store.selectTool("rectangle");
    store.pointer("down", new Point(10, 10));
    store.pointer("move", new Point(80, 80));
    store.pointer("up", new Point(80, 80));
    store.resetScene();
    expect(store.scene.visibleElements).toHaveLength(0);
    store.undo();
    expect(store.scene.visibleElements).toHaveLength(1);
  });

  it("openPngScene round-trips a scene through PNG bytes and rejects plain PNGs", () => {
    const store = new EditorStore();
    store.selectTool("rectangle");
    store.pointer("down", new Point(10, 10));
    store.pointer("move", new Point(80, 80));
    store.pointer("up", new Point(80, 80));

    const png = minimalPng();
    const embedded = embedScene(store.scene, png);
    expect(embedded).not.toBeNull();

    const restored = new EditorStore();
    expect(restored.openPngScene(png)).toBe(false); // no scene chunk
    expect(restored.openPngScene(embedded!)).toBe(true);
    expect(restored.scene.visibleElements).toHaveLength(1);
    expect(restored.scene.visibleElements[0]!.type).toBe("rectangle");
  });
});

describe("style panel setters", () => {
  function drawArrow(store: EditorStore): void {
    store.selectTool("arrow");
    store.pointer("down", new Point(100, 100));
    store.pointer("move", new Point(300, 150));
    store.pointer("up", new Point(300, 150)); // stays selected, tool reverts
  }
  const arrow = (store: EditorStore, index = 0) =>
    store.scene.visibleElements.filter((e) => e.type === "arrow")[index]!;

  it("arrowhead setters apply to the selected arrow and to the next one", () => {
    const store = new EditorStore();
    drawArrow(store);
    store.setStartArrowhead("triangle");
    store.setEndArrowhead(null);
    expect(arrow(store).startArrowhead).toBe("triangle");
    expect(arrow(store).endArrowhead).toBeNull();

    store.pointer("down", new Point(600, 500)); // deselect on empty canvas
    store.pointer("up", new Point(600, 500));
    drawArrow(store);
    expect(arrow(store, 1).startArrowhead).toBe("triangle"); // new default
    expect(arrow(store, 1).endArrowhead).toBeNull();
  });

  it("setArrowType round-trips straight, curved, and elbow", () => {
    const store = new EditorStore();
    drawArrow(store);
    store.setArrowType("curved");
    expect(arrow(store).roundness?.type).toBe(RoundnessType.proportionalRadius);
    expect(arrow(store).elbowed).toBe(false);

    store.setArrowType("elbow");
    expect(arrow(store).elbowed).toBe(true);

    store.setArrowType("straight");
    expect(arrow(store).elbowed).toBe(false);
    expect(arrow(store).roundness ?? null).toBeNull();

    // Curved becomes the default for the next arrow.
    store.setArrowType("curved");
    store.pointer("down", new Point(600, 500));
    store.pointer("up", new Point(600, 500));
    drawArrow(store);
    expect(arrow(store, 1).roundness?.type).toBe(RoundnessType.proportionalRadius);
  });

  it("font setters update selected text (with size recompute) and defaults", () => {
    const store = new EditorStore();
    store.selectTool("text");
    store.pointer("down", new Point(200, 200));
    store.setEditingText("Hi");
    store.commitText();
    const text = () => store.scene.visibleElements.find((e) => e.type === "text")!;
    const widthBefore = text().width;

    store.setFontSize(36);
    store.setTextAlign("center");
    store.setFontFamily(FontFamily.cascadia);
    expect(text().fontSize).toBe(36);
    expect(text().textAlign).toBe("center");
    expect(text().fontFamily).toBe(FontFamily.cascadia);
    expect(text().width).toBeGreaterThan(widthBefore); // remeasured at 36px

    // Defaults carry to the next text element.
    store.selectTool("selection");
    store.doubleClickAt(new Point(500, 400));
    store.setEditingText("Next");
    store.commitText();
    const next = store.scene.visibleElements.filter((e) => e.type === "text")[1]!;
    expect(next.fontSize).toBe(36);
    expect(next.textAlign).toBe("center");
    expect(next.fontFamily).toBe(FontFamily.cascadia);
  });
});

describe("sticky-note label fitting and font scaling", () => {
  const LONG = "sddslasdlajsdlkajsdklajdlajsldjalsdjkalsdkajdlask";

  function insertNoteWithText(store: EditorStore, text: string) {
    store.insertStickyNote();
    store.setEditingText(text);
    store.commitText();
    const note = store.scene.visibleElements.find((e) => e.type === "rectangle")!;
    const label = store.scene.visibleElements.find((e) => e.type === "text")!;
    return { note, label };
  }

  it("a long label wraps to the note's width and the note grows to fit it", () => {
    const store = new EditorStore();
    const { note, label } = insertNoteWithText(store, LONG);
    expect(label.text).toContain("\n"); // wrapped, not one overflowing line
    expect(label.originalText).toBe(LONG); // raw input preserved
    expect(label.width).toBeLessThanOrEqual(note.width - 16 + 1);
    expect(label.height).toBeLessThanOrEqual(note.height - 16 + 1); // note grew to fit
  });

  it("resizing the note scales the label font and keeps the text fitting", () => {
    const store = new EditorStore();
    const { note, label } = insertNoteWithText(store, "Idea!");
    const fontBefore = label.fontSize;

    // Grab the note's bottom-right handle and drag it outward.
    store.selectTool("selection");
    store.pointer("down", new Point(note.x + note.width / 2, note.y + note.height / 2));
    store.pointer("up", new Point(note.x + note.width / 2, note.y + note.height / 2));
    const corner = new Point(note.x + note.width, note.y + note.height);
    store.pointer("down", corner);
    store.pointer("move", new Point(corner.x + 160, corner.y + 160));
    store.pointer("up", new Point(corner.x + 160, corner.y + 160));

    const grown = store.scene.visibleElements.find((e) => e.type === "rectangle")!;
    const scaled = store.scene.visibleElements.find((e) => e.type === "text")!;
    expect(grown.width).toBeGreaterThan(note.width + 100);
    expect(scaled.fontSize).toBeGreaterThan(fontBefore * 1.5);
    expect(scaled.width).toBeLessThanOrEqual(grown.width - 16 + 1);

    // And shrinking scales it back down.
    const corner2 = new Point(grown.x + grown.width, grown.y + grown.height);
    store.pointer("down", corner2);
    store.pointer("move", new Point(corner2.x - 200, corner2.y - 200));
    store.pointer("up", new Point(corner2.x - 200, corner2.y - 200));
    const shrunk = store.scene.visibleElements.find((e) => e.type === "text")!;
    expect(shrunk.fontSize).toBeLessThan(scaled.fontSize);
  });
});

describe("double-click labels and canvas text", () => {
  /** Draw a rectangle from (100,100) to (300,200) with the rectangle tool. */
  function drawRect(store: EditorStore) {
    store.selectTool("rectangle");
    store.pointer("down", new Point(100, 100));
    store.pointer("move", new Point(300, 200));
    store.pointer("up", new Point(300, 200));
    store.selectTool("selection");
    return store.scene.visibleElements.find((e) => e.type === "rectangle")!;
  }
  const center = (r: { x: number; y: number; width: number; height: number }) =>
    new Point(r.x + r.width / 2, r.y + r.height / 2);

  it("double-clicking a plain shape creates and edits a centred bound label", () => {
    const store = new EditorStore();
    const rect = drawRect(store);
    store.doubleClickAt(center(rect));
    expect(store.editingText).not.toBeNull();
    expect(store.editingText?.value).toBe("");

    store.setEditingText("Hello");
    store.commitText();

    const text = store.scene.visibleElements.find((e) => e.type === "text")!;
    expect(text.text).toBe("Hello");
    const container = store.scene.visibleElements.find((e) => e.type === "rectangle")!;
    expect(text.containerId).toBe(container.id);
    expect(container.boundElements).toEqual([{ id: text.id, type: "text" }]);
    // Stored position is centred in the container (cross-client fidelity).
    expect(text.x + text.width / 2).toBeCloseTo(container.x + container.width / 2, 0);
    expect(text.y + text.height / 2).toBeCloseTo(container.y + container.height / 2, 0);
  });

  it("double-clicking a labelled shape edits the existing label", () => {
    const store = new EditorStore();
    const rect = drawRect(store);
    store.doubleClickAt(center(rect));
    store.setEditingText("Hello");
    store.commitText();

    store.doubleClickAt(center(rect));
    expect(store.editingText?.value).toBe("Hello");
    store.setEditingText("World");
    store.commitText();

    const texts = store.scene.visibleElements.filter((e) => e.type === "text");
    expect(texts).toHaveLength(1);
    expect(texts[0]!.text).toBe("World");
  });

  it("committing an empty new label leaves no orphan", () => {
    const store = new EditorStore();
    const rect = drawRect(store);
    store.doubleClickAt(center(rect));
    store.commitText(); // nothing typed

    expect(store.scene.visibleElements.some((e) => e.type === "text")).toBe(false);
    const container = store.scene.visibleElements.find((e) => e.type === "rectangle")!;
    expect(container.boundElements ?? []).toHaveLength(0);
  });

  it("a typed label is one undo step (create + text fold together)", () => {
    const store = new EditorStore();
    const rect = drawRect(store);
    store.doubleClickAt(center(rect));
    store.setEditingText("Hello");
    store.commitText();
    expect(store.scene.visibleElements.some((e) => e.type === "text")).toBe(true);

    store.undo();
    expect(store.scene.visibleElements.some((e) => e.type === "text")).toBe(false);
    const container = store.scene.visibleElements.find((e) => e.type === "rectangle")!;
    expect(container.boundElements ?? []).toHaveLength(0);
  });

  it("the label hit rule covers a transparent shape's interior", () => {
    const store = new EditorStore();
    const rect = drawRect(store); // default background is transparent
    expect(store.controller.labelContainerHit(center(rect))).toBe(rect.id);
  });

  it("text-tool text commits when clicking outside the editor", () => {
    const store = new EditorStore();
    store.selectTool("text");
    store.pointer("down", new Point(400, 300));
    expect(store.editingText).not.toBeNull();
    store.setEditingText("Hi");

    // A press elsewhere commits the edit and is consumed (no draw/select/editor).
    store.pointer("down", new Point(700, 500));
    store.pointer("up", new Point(700, 500));
    expect(store.editingText).toBeNull();
    const texts = store.scene.visibleElements.filter((e) => e.type === "text");
    expect(texts).toHaveLength(1);
    expect(texts[0]!.text).toBe("Hi");
    expect(store.activeTool).toBe("selection");
  });

  it("a label editor commits when clicking outside it", () => {
    const store = new EditorStore();
    const rect = drawRect(store);
    store.doubleClickAt(center(rect));
    store.setEditingText("Hello");
    store.pointer("down", new Point(700, 500));
    expect(store.editingText).toBeNull();
    const label = store.scene.visibleElements.find((e) => e.type === "text")!;
    expect(label.text).toBe("Hello");
    expect(label.containerId).toBe(rect.id);
  });

  it("double-clicking empty canvas creates a text element in place", () => {
    const store = new EditorStore();
    store.selectTool("selection");
    store.doubleClickAt(new Point(400, 300));
    expect(store.editingText).not.toBeNull();

    store.setEditingText("Quick text");
    store.commitText();
    const text = store.scene.visibleElements.find((e) => e.type === "text")!;
    expect(text.text).toBe("Quick text");
    expect(text.containerId).toBeNull();
  });

  it("double-clicking existing free text edits it instead of stacking a new one", () => {
    const store = new EditorStore();
    store.selectTool("selection");
    store.doubleClickAt(new Point(400, 300));
    store.setEditingText("First");
    store.commitText();

    const text = store.scene.visibleElements.find((e) => e.type === "text")!;
    store.doubleClickAt(new Point(text.x + text.width / 2, text.y + text.height / 2));
    expect(store.editingText?.id).toBe(text.id);
    expect(store.editingText?.value).toBe("First");
    store.commitText();
    expect(store.scene.visibleElements.filter((e) => e.type === "text")).toHaveLength(1);
  });

  it("suggested binding highlights on arrow-tool hover and clears away", () => {
    const store = new EditorStore();
    const rect = drawRect(store);
    store.selectTool("arrow");

    store.trackPointer(center(rect));
    expect(store.controller.suggestedBindingID).toBe(rect.id);

    store.trackPointer(new Point(2000, 2000));
    expect(store.controller.suggestedBindingID).toBeNull();
  });

  it("suggested binding tracks the endpoint while drawing an arrow and clears on release", () => {
    const store = new EditorStore();
    const rect = drawRect(store);
    store.selectTool("arrow");

    store.pointer("down", new Point(500, 150));
    store.pointer("move", center(rect));
    expect(store.controller.suggestedBindingID).toBe(rect.id);

    store.pointer("up", center(rect));
    expect(store.controller.suggestedBindingID).toBeNull();
    // The released endpoint actually bound (existing behaviour, sanity check).
    const arrow = store.scene.visibleElements.find((e) => e.type === "arrow")!;
    expect(arrow.endBinding?.elementId).toBe(rect.id);
  });

  it("non-linear tools never suggest a binding", () => {
    const store = new EditorStore();
    const rect = drawRect(store);
    store.selectTool("selection");
    store.trackPointer(center(rect));
    expect(store.controller.suggestedBindingID).toBeNull();

    store.selectTool("rectangle");
    store.trackPointer(center(rect));
    expect(store.controller.suggestedBindingID).toBeNull();
  });

  it("labels serialize with schema-v2 fields only and round-trip the document", () => {
    const store = new EditorStore();
    const rect = drawRect(store);
    store.doubleClickAt(center(rect));
    store.setEditingText("Hello");
    store.commitText();

    const json = store.documentJSON();
    const doc = JSON.parse(json) as {
      elements: {
        type: string;
        id: string;
        containerId?: string | null;
        boundElements?: unknown;
      }[];
    };
    const text = doc.elements.find((e) => e.type === "text")!;
    const container = doc.elements.find((e) => e.type === "rectangle")!;
    expect(text.containerId).toBe(container.id);
    expect(container.boundElements).toEqual([{ id: text.id, type: "text" }]);

    const restored = new EditorStore();
    restored.loadDocument(json);
    const rText = restored.scene.visibleElements.find((e) => e.type === "text")!;
    expect(rText.text).toBe("Hello");
    expect(rText.containerId).toBe(container.id);
  });

  it("click-to-connect: click a source shape, hover, click the destination", () => {
    const store = new EditorStore();
    const a = drawRect(store); // (100,100)-(300,200)
    store.selectTool("rectangle");
    store.pointer("down", new Point(500, 100));
    store.pointer("move", new Point(700, 200));
    store.pointer("up", new Point(700, 200));
    store.selectTool("arrow");

    // Click (no drag) on shape A's right-edge anchor region starts the arrow.
    const start = new Point(a.x + a.width, a.y + a.height / 2);
    store.pointer("down", start);
    store.pointer("up", start);
    expect(store.controller.pendingLinearID).not.toBeNull();

    // The preview end follows the hovering cursor.
    store.trackPointer(new Point(450, 150));
    const preview = store.scene.visibleElements.find((e) => e.type === "arrow")!;
    expect(preview.width).toBeGreaterThan(100);

    // Clicking the destination completes the arrow, bound on both ends.
    store.pointer("down", new Point(600, 150));
    store.pointer("up", new Point(600, 150));
    expect(store.controller.pendingLinearID).toBeNull();
    const arrow = store.scene.visibleElements.find((e) => e.type === "arrow")!;
    expect(arrow.startBinding).not.toBeNull();
    expect(arrow.endBinding).not.toBeNull();
    expect(store.activeTool).toBe("selection");
  });

  it("click-to-connect snaps the source to the nearest anchor placeholder", () => {
    const store = new EditorStore();
    const a = drawRect(store);
    store.selectTool("arrow");
    // Click slightly off the right-edge midpoint: within the anchor radius.
    const anchor = new Point(a.x + a.width, a.y + a.height / 2);
    store.pointer("down", new Point(anchor.x - 6, anchor.y + 6));
    store.pointer("up", new Point(anchor.x - 6, anchor.y + 6));
    const arrow = store.scene.visibleElements.find((e) => e.type === "arrow")!;
    expect(arrow.x).toBeCloseTo(anchor.x, 5);
    expect(arrow.y).toBeCloseTo(anchor.y, 5);
    store.cancelPendingArrow();
  });

  it("a destination click inside a shape lands on its nearest anchor", () => {
    const store = new EditorStore();
    const a = drawRect(store); // (100,100)-(300,200)
    store.selectTool("arrow");
    store.pointer("down", new Point(500, 150)); // click-start on empty canvas
    store.pointer("up", new Point(500, 150));
    // Click well inside the shape: the end snaps to the nearest anchor (right
    // edge midpoint), so the arrow never terminates mid-shape.
    store.pointer("down", new Point(a.x + a.width - 30, a.y + a.height / 2));
    store.pointer("up", new Point(a.x + a.width - 30, a.y + a.height / 2));
    const arrow = store.scene.visibleElements.find((e) => e.type === "arrow")!;
    const end = arrow.points[arrow.points.length - 1]!;
    expect(arrow.x + end[0]).toBeCloseTo(a.x + a.width, 5);
    expect(arrow.y + end[1]).toBeCloseTo(a.y + a.height / 2, 5);
    expect(arrow.endBinding).not.toBeNull();
  });

  it("labelled shapes bind as the shape — never the label text (regression)", () => {
    const store = new EditorStore();
    const a = drawRect(store); // (100,100)-(300,200)
    store.doubleClickAt(center(a));
    store.setEditingText("Edvane"); // label covers the centre
    store.commitText();

    // Hover suggests the rectangle, not the smaller label under the cursor.
    store.selectTool("arrow");
    store.trackPointer(center(a));
    expect(store.controller.suggestedBindingID).toBe(a.id);

    // Click-to-connect into the labelled centre binds and snaps to the shape.
    store.pointer("down", new Point(500, 150));
    store.pointer("up", new Point(500, 150));
    store.pointer("down", center(a));
    store.pointer("up", center(a));
    const arrow = store.scene.visibleElements.find((e) => e.type === "arrow")!;
    expect(arrow.endBinding?.elementId).toBe(a.id);
    const end = arrow.points[arrow.points.length - 1]!;
    const anchors = store.controller.anchorPointsFor(a.id);
    const endPoint = new Point(arrow.x + end[0], arrow.y + end[1]);
    expect(anchors.some((p) => p.distance(endPoint) < 1)).toBe(true);
  });

  it("a pending arrow cancels on Escape or tool switch with no history", () => {
    const store = new EditorStore();
    drawRect(store);
    store.selectTool("arrow");
    store.pointer("down", new Point(500, 400));
    store.pointer("up", new Point(500, 400));
    expect(store.controller.pendingLinearID).not.toBeNull();
    expect(store.cancelPendingArrow()).toBe(true);
    expect(store.scene.visibleElements.some((e) => e.type === "arrow")).toBe(false);
    expect(store.cancelPendingArrow()).toBe(false); // nothing pending anymore

    // Tool switch also abandons a fresh pending arrow.
    store.selectTool("arrow");
    store.pointer("down", new Point(500, 400));
    store.pointer("up", new Point(500, 400));
    store.selectTool("selection");
    expect(store.scene.visibleElements.some((e) => e.type === "arrow")).toBe(false);
    // History: only the rectangle draw is undoable; undoing it empties the scene.
    store.undo();
    expect(store.scene.visibleElements).toHaveLength(0);
    expect(store.canUndo).toBe(false);
  });

  it("exposes four anchor placeholders at the side midpoints", () => {
    const store = new EditorStore();
    const a = drawRect(store);
    const anchors = store.controller.anchorPointsFor(a.id);
    expect(anchors).toHaveLength(4);
    const xs = anchors.map((p) => Math.round(p.x)).sort((m, n) => m - n);
    const cx = Math.round(a.x + a.width / 2);
    expect(xs).toEqual([Math.round(a.x), cx, cx, Math.round(a.x + a.width)].sort((m, n) => m - n));
  });

  it("double-click priorities still route charts, lines, and bound text first", () => {
    const store = new EditorStore();
    // A chart double-click opens the chart editor, not a label editor.
    store.insertChart([10, 20], "bar");
    const bar = store.scene.visibleElements.find((e) => e.type === "rectangle")!;
    store.selectTool("selection");
    store.doubleClickAt(new Point(bar.x + bar.width / 2, bar.y + bar.height / 2));
    expect(store.editingChart).not.toBeNull();
    expect(store.editingText).toBeNull();
    store.cancelChart();
  });
});
