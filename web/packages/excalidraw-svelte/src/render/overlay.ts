import type { BoundingBox } from "../geometry/index.js";
import type { Point } from "../math/index.js";
import type { RenderContext } from "./scene-renderer.js";
import type { Viewport } from "./viewport.js";

/** Interaction-overlay colours; clients may override any of them. */
export interface OverlayColors {
  /** Selection box, handles, and linear-edit points. */
  accent?: string;
  /** Marquee fill. */
  accentFill?: string;
  /** Suggested-binding ring and anchor placeholders. */
  bindingHighlight?: string;
  /** Object/gap snap guides. */
  snap?: string;
  /** Handle interiors. */
  handleFill?: string;
}

export const defaultOverlayColors: Required<OverlayColors> = {
  accent: "#6b82f5", // Excalidraw violet
  accentFill: "rgba(107,130,245,0.08)",
  bindingHighlight: "#68b1ec", // suggested-binding ring (excalidraw blue)
  snap: "rgba(232,77,61,0.9)",
  handleFill: "#ffffff",
};
const TWO_PI = Math.PI * 2;

export interface TrailDot {
  position: Point;
  time: number;
}

export interface OverlayOptions {
  viewport: Viewport;
  width: number;
  height: number;
  selectionBounds?: BoundingBox | null;
  handles?: Point[];
  rotationHandle?: Point | null;
  selectionRect?: BoundingBox | null;
  snapLinesX?: number[];
  snapLinesY?: number[];
  linearPoints?: Point[];
  linearMidpoints?: Point[];
  cropFrame?: BoundingBox | null;
  cropHandles?: Point[];
  handleSizePx?: number;
  /** Current time (seconds) for fading the laser/eraser trails. */
  now?: number;
  laserDots?: TrailDot[];
  eraserDots?: TrailDot[];
  /** Remote collaborators' cursors (scene coords), drawn in each peer's colour. */
  remoteCursors?: { color: string; name: string; x: number; y: number }[];
  /** Closed outline (scene coords) of the shape a linear endpoint would bind to. */
  suggestedOutline?: Point[];
  /** Anchor placeholders (side midpoints) where a click-to-connect arrow can
   * start or stop on the suggested shape. */
  suggestedAnchors?: Point[];
  /** Overlay colour overrides (defaults are the excalidraw-like palette). */
  colors?: OverlayColors;
}

const TRAIL_FADE = 0.7;

function drawTrail(
  ctx: RenderContext,
  dots: TrailDot[],
  now: number,
  color: string,
  width: number,
): void {
  if (dots.length < 2) return;
  ctx.strokeStyle = color;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.lineWidth = width;
  ctx.setLineDash([]);
  for (let i = 1; i < dots.length; i++) {
    const alpha = 1 - (now - dots[i]!.time) / TRAIL_FADE;
    if (alpha <= 0) continue;
    ctx.globalAlpha = alpha;
    ctx.beginPath();
    ctx.moveTo(dots[i - 1]!.position.x, dots[i - 1]!.position.y);
    ctx.lineTo(dots[i]!.position.x, dots[i]!.position.y);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}

function squareHandle(
  ctx: RenderContext,
  p: Point,
  size: number,
  lineWidth: number,
  colors: Required<OverlayColors>,
): void {
  const { accent: ACCENT, handleFill: WHITE } = colors;
  ctx.fillStyle = WHITE;
  ctx.fillRect(p.x - size / 2, p.y - size / 2, size, size);
  ctx.strokeStyle = ACCENT;
  ctx.lineWidth = lineWidth;
  ctx.strokeRect(p.x - size / 2, p.y - size / 2, size, size);
}

function circleHandle(
  ctx: RenderContext,
  p: Point,
  size: number,
  lineWidth: number,
  colors: Required<OverlayColors>,
): void {
  const { accent: ACCENT, handleFill: WHITE } = colors;
  ctx.beginPath();
  ctx.arc(p.x, p.y, size / 2, 0, TWO_PI);
  ctx.fillStyle = WHITE;
  ctx.fill();
  ctx.strokeStyle = ACCENT;
  ctx.lineWidth = lineWidth;
  ctx.stroke();
}

/**
 * Draw the interactive overlay (selection box, transform handles, marquee, snap
 * guides, linear/crop edit handles) on top of the scene. (parity:
 * InteractiveRenderer.swift)
 */
export function renderOverlay(ctx: RenderContext, o: OverlayOptions): void {
  const v = o.viewport;
  const colors: Required<OverlayColors> = { ...defaultOverlayColors, ...o.colors };
  const {
    accent: ACCENT,
    accentFill: ACCENT_FILL,
    bindingHighlight: BINDING_HIGHLIGHT,
    snap: SNAP,
    handleFill: WHITE,
  } = colors;
  ctx.save();
  ctx.scale(v.zoom, v.zoom);
  ctx.translate(v.scrollX, v.scrollY);

  const lineWidth = 1 / v.zoom;
  const handleSize = (o.handleSizePx ?? 8) / v.zoom;

  // Suggested-binding highlight: ring the shape a linear endpoint would bind
  // to, under all other overlay chrome.
  const suggested = o.suggestedOutline ?? [];
  if (suggested.length > 1) {
    ctx.strokeStyle = BINDING_HIGHLIGHT;
    ctx.lineWidth = 4 / v.zoom;
    ctx.setLineDash([]);
    ctx.beginPath();
    ctx.moveTo(suggested[0]!.x, suggested[0]!.y);
    for (let i = 1; i < suggested.length; i++) ctx.lineTo(suggested[i]!.x, suggested[i]!.y);
    ctx.closePath();
    ctx.stroke();
  }
  // Anchor placeholders: where a click-to-connect arrow starts/stops.
  for (const anchor of o.suggestedAnchors ?? []) {
    ctx.beginPath();
    ctx.arc(anchor.x, anchor.y, 5 / v.zoom, 0, TWO_PI);
    ctx.fillStyle = WHITE;
    ctx.fill();
    ctx.strokeStyle = BINDING_HIGHLIGHT;
    ctx.lineWidth = 2 / v.zoom;
    ctx.setLineDash([]);
    ctx.stroke();
  }
  const snapLinesX = o.snapLinesX ?? [];
  const snapLinesY = o.snapLinesY ?? [];

  if (snapLinesX.length > 0 || snapLinesY.length > 0) {
    const topLeft = v.viewToScene({ x: 0, y: 0 } as Point);
    const bottomRight = v.viewToScene({ x: o.width, y: o.height } as Point);
    ctx.strokeStyle = SNAP;
    ctx.lineWidth = lineWidth;
    ctx.setLineDash([]);
    ctx.beginPath();
    for (const x of snapLinesX) {
      ctx.moveTo(x, topLeft.y);
      ctx.lineTo(x, bottomRight.y);
    }
    for (const y of snapLinesY) {
      ctx.moveTo(topLeft.x, y);
      ctx.lineTo(bottomRight.x, y);
    }
    ctx.stroke();
  }

  const rect = o.selectionRect ?? null;
  if (rect !== null) {
    ctx.strokeStyle = ACCENT;
    ctx.lineWidth = lineWidth;
    ctx.setLineDash([4 / v.zoom, 4 / v.zoom]);
    ctx.strokeRect(rect.minX, rect.minY, rect.width, rect.height);
    ctx.fillStyle = ACCENT_FILL;
    ctx.fillRect(rect.minX, rect.minY, rect.width, rect.height);
    ctx.setLineDash([]);
  }

  const bounds = o.selectionBounds ?? null;
  if (bounds !== null) {
    ctx.strokeStyle = ACCENT;
    ctx.lineWidth = lineWidth;
    ctx.setLineDash([]);
    ctx.strokeRect(bounds.minX, bounds.minY, bounds.width, bounds.height);
    const rotationHandle = o.rotationHandle ?? null;
    if (rotationHandle !== null) {
      ctx.beginPath();
      ctx.moveTo((bounds.minX + bounds.maxX) / 2, bounds.minY);
      ctx.lineTo(rotationHandle.x, rotationHandle.y);
      ctx.stroke();
      circleHandle(ctx, rotationHandle, handleSize, lineWidth, colors);
    }
    for (const handle of o.handles ?? []) squareHandle(ctx, handle, handleSize, lineWidth, colors);
  }

  const cropFrame = o.cropFrame ?? null;
  if (cropFrame !== null) {
    ctx.strokeStyle = ACCENT;
    ctx.lineWidth = lineWidth * 2;
    ctx.setLineDash([]);
    ctx.strokeRect(cropFrame.minX, cropFrame.minY, cropFrame.width, cropFrame.height);
    for (const handle of o.cropHandles ?? [])
      squareHandle(ctx, handle, handleSize, lineWidth, colors);
  }

  for (const mid of o.linearMidpoints ?? [])
    circleHandle(ctx, mid, handleSize * 0.8, lineWidth, colors);
  for (const p of o.linearPoints ?? []) {
    ctx.beginPath();
    ctx.arc(p.x, p.y, handleSize / 2, 0, TWO_PI);
    ctx.fillStyle = ACCENT;
    ctx.fill();
  }

  const now = o.now ?? 0;
  drawTrail(ctx, o.laserDots ?? [], now, "#ff2d2d", 4 / v.zoom);
  drawTrail(ctx, o.eraserDots ?? [], now, "#9aa0a6", 10 / v.zoom);

  for (const cursor of o.remoteCursors ?? []) {
    const s = 1 / v.zoom;
    // A small arrowhead pointing up-left at the cursor position.
    ctx.beginPath();
    ctx.moveTo(cursor.x, cursor.y);
    ctx.lineTo(cursor.x + 12 * s, cursor.y + 4 * s);
    ctx.lineTo(cursor.x + 4 * s, cursor.y + 12 * s);
    ctx.closePath();
    ctx.fillStyle = cursor.color;
    ctx.fill();
    // Name tag.
    ctx.font = `${12 * s}px sans-serif`;
    ctx.fillText(cursor.name, cursor.x + 14 * s, cursor.y + 20 * s);
  }

  ctx.restore();
}
