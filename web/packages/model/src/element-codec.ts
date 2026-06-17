import type {
  ArrowElement,
  BaseProperties,
  ExcalidrawElement,
  FrameElement,
  FreedrawElement,
  ImageElement,
  LinearElement,
  TextElement,
} from "./element.js";
import { FontFamily } from "./enums.js";
import type {
  Arrowhead,
  FillStyle,
  ImageStatus,
  StrokeStyle,
  TextAlign,
  VerticalAlign,
} from "./enums.js";
import type {
  BoundElement,
  FixedPointBinding,
  FixedSegment,
  ImageCrop,
  JSONValue,
  LocalPoint,
  Roundness,
} from "./value-types.js";

type Raw = Record<string, unknown>;

function num(o: Raw, k: string, def: number): number {
  const v = o[k];
  return typeof v === "number" ? v : def;
}
function str(o: Raw, k: string, def: string): string {
  const v = o[k];
  return typeof v === "string" ? v : def;
}
function bool(o: Raw, k: string, def: boolean): boolean {
  const v = o[k];
  return typeof v === "boolean" ? v : def;
}
function optStr(o: Raw, k: string): string | null {
  const v = o[k];
  return typeof v === "string" ? v : null;
}
function points(o: Raw, k: string): LocalPoint[] {
  const v = o[k];
  return Array.isArray(v) ? (v as LocalPoint[]) : [];
}

/** Decode the base properties shared by every element, leniently. */
function decodeBase(o: Raw): BaseProperties {
  const base: BaseProperties = {
    id: str(o, "id", ""),
    x: num(o, "x", 0),
    y: num(o, "y", 0),
    width: num(o, "width", 0),
    height: num(o, "height", 0),
    angle: num(o, "angle", 0),
    strokeColor: str(o, "strokeColor", "#1e1e1e"),
    backgroundColor: str(o, "backgroundColor", "transparent"),
    fillStyle: str(o, "fillStyle", "solid") as FillStyle,
    strokeWidth: num(o, "strokeWidth", 2),
    strokeStyle: str(o, "strokeStyle", "solid") as StrokeStyle,
    roundness: (o.roundness as Roundness | null) ?? null,
    roughness: num(o, "roughness", 1),
    opacity: num(o, "opacity", 100),
    seed: num(o, "seed", 1),
    version: num(o, "version", 1),
    versionNonce: num(o, "versionNonce", 0),
    index: optStr(o, "index"),
    isDeleted: bool(o, "isDeleted", false),
    groupIds: Array.isArray(o.groupIds) ? (o.groupIds as string[]) : [],
    frameId: optStr(o, "frameId"),
    boundElements: Array.isArray(o.boundElements) ? (o.boundElements as BoundElement[]) : null,
    updated: num(o, "updated", 0),
    link: optStr(o, "link"),
    locked: bool(o, "locked", false),
  };
  if (o.customData !== undefined && o.customData !== null) {
    base.customData = o.customData as Record<string, JSONValue>;
  }
  return base;
}

/** Decode one element from its flat JSON object; throws on an unknown `type`. */
export function decodeElement(o: Raw): ExcalidrawElement {
  const base = decodeBase(o);
  const type = o.type;
  switch (type) {
    case "selection":
    case "rectangle":
    case "diamond":
    case "ellipse":
    case "embeddable":
    case "iframe":
      return { ...base, type };
    case "text":
      return {
        ...base,
        type,
        fontSize: num(o, "fontSize", 20),
        fontFamily: num(o, "fontFamily", FontFamily.default),
        text: str(o, "text", ""),
        textAlign: str(o, "textAlign", "left") as TextAlign,
        verticalAlign: str(o, "verticalAlign", "top") as VerticalAlign,
        containerId: optStr(o, "containerId"),
        originalText: str(o, "originalText", str(o, "text", "")),
        autoResize: bool(o, "autoResize", true),
        lineHeight: num(o, "lineHeight", 1.25),
      } satisfies TextElement;
    case "freedraw":
      return {
        ...base,
        type,
        points: points(o, "points"),
        pressures: Array.isArray(o.pressures) ? (o.pressures as number[]) : [],
        simulatePressure: bool(o, "simulatePressure", true),
      } satisfies FreedrawElement;
    case "line":
      return {
        ...base,
        type,
        points: points(o, "points"),
        startBinding: (o.startBinding as FixedPointBinding | null) ?? null,
        endBinding: (o.endBinding as FixedPointBinding | null) ?? null,
        startArrowhead: (o.startArrowhead as Arrowhead | null) ?? null,
        endArrowhead: (o.endArrowhead as Arrowhead | null) ?? null,
        polygon: bool(o, "polygon", false),
      } satisfies LinearElement;
    case "arrow": {
      const el: ArrowElement = {
        ...base,
        type,
        points: points(o, "points"),
        startBinding: (o.startBinding as FixedPointBinding | null) ?? null,
        endBinding: (o.endBinding as FixedPointBinding | null) ?? null,
        startArrowhead: (o.startArrowhead as Arrowhead | null) ?? null,
        endArrowhead: (o.endArrowhead as Arrowhead | null) ?? null,
        elbowed: bool(o, "elbowed", false),
      };
      if (Array.isArray(o.fixedSegments)) el.fixedSegments = o.fixedSegments as FixedSegment[];
      if (typeof o.startIsSpecial === "boolean") el.startIsSpecial = o.startIsSpecial;
      if (typeof o.endIsSpecial === "boolean") el.endIsSpecial = o.endIsSpecial;
      return el;
    }
    case "image":
      return {
        ...base,
        type,
        fileId: optStr(o, "fileId"),
        status: str(o, "status", "pending") as ImageStatus,
        scale: (Array.isArray(o.scale) ? o.scale : [1, 1]) as LocalPoint,
        crop: (o.crop as ImageCrop | null) ?? null,
      } satisfies ImageElement;
    case "frame":
    case "magicframe":
      return { ...base, type, name: optStr(o, "name") } satisfies FrameElement;
    default:
      throw new Error(`Unknown element type "${String(type)}"`);
  }
}

/** Encode the base properties into the canonical flat key set (nulls included). */
function encodeBase(el: BaseProperties): Raw {
  const o: Raw = {
    id: el.id,
    x: el.x,
    y: el.y,
    width: el.width,
    height: el.height,
    angle: el.angle,
    strokeColor: el.strokeColor,
    backgroundColor: el.backgroundColor,
    fillStyle: el.fillStyle,
    strokeWidth: el.strokeWidth,
    strokeStyle: el.strokeStyle,
    roundness: el.roundness ?? null,
    roughness: el.roughness,
    opacity: el.opacity,
    seed: el.seed,
    version: el.version,
    versionNonce: el.versionNonce,
    index: el.index ?? null,
    isDeleted: el.isDeleted,
    groupIds: el.groupIds,
    frameId: el.frameId ?? null,
    boundElements: el.boundElements ?? null,
    updated: el.updated,
    link: el.link ?? null,
    locked: el.locked,
  };
  if (el.customData !== undefined) o.customData = el.customData;
  return o;
}

/** Encode one element to its canonical flat JSON object. */
export function encodeElement(el: ExcalidrawElement): Raw {
  const o = encodeBase(el);
  o.type = el.type;
  switch (el.type) {
    case "text":
      o.fontSize = el.fontSize;
      o.fontFamily = el.fontFamily;
      o.text = el.text;
      o.textAlign = el.textAlign;
      o.verticalAlign = el.verticalAlign;
      o.containerId = el.containerId ?? null;
      o.originalText = el.originalText;
      o.autoResize = el.autoResize;
      o.lineHeight = el.lineHeight;
      break;
    case "freedraw":
      o.points = el.points;
      o.pressures = el.pressures;
      o.simulatePressure = el.simulatePressure;
      break;
    case "line":
      o.points = el.points;
      o.startBinding = el.startBinding ?? null;
      o.endBinding = el.endBinding ?? null;
      o.startArrowhead = el.startArrowhead ?? null;
      o.endArrowhead = el.endArrowhead ?? null;
      o.polygon = el.polygon;
      break;
    case "arrow":
      o.points = el.points;
      o.startBinding = el.startBinding ?? null;
      o.endBinding = el.endBinding ?? null;
      o.startArrowhead = el.startArrowhead ?? null;
      o.endArrowhead = el.endArrowhead ?? null;
      o.elbowed = el.elbowed;
      if (el.elbowed) {
        if (el.fixedSegments !== undefined) o.fixedSegments = el.fixedSegments;
        if (el.startIsSpecial !== undefined) o.startIsSpecial = el.startIsSpecial;
        if (el.endIsSpecial !== undefined) o.endIsSpecial = el.endIsSpecial;
      }
      break;
    case "image":
      o.fileId = el.fileId ?? null;
      o.status = el.status;
      o.scale = el.scale;
      o.crop = el.crop ?? null;
      break;
    case "frame":
    case "magicframe":
      o.name = el.name ?? null;
      break;
    default:
      break; // generic shapes carry no type-specific fields
  }
  return o;
}
