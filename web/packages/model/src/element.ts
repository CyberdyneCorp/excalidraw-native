import type {
  Arrowhead,
  ElementType,
  FillStyle,
  ImageStatus,
  StrokeStyle,
  TextAlign,
  VerticalAlign,
} from "./enums.js";
import { FontFamily } from "./enums.js";
import type {
  BoundElement,
  FixedPointBinding,
  FixedSegment,
  ImageCrop,
  JSONValue,
  LocalPoint,
  Roundness,
} from "./value-types.js";

/** Fields shared by every Excalidraw element (`_ExcalidrawElementBase`). */
export interface BaseProperties {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
  angle: number;
  strokeColor: string;
  backgroundColor: string;
  fillStyle: FillStyle;
  strokeWidth: number;
  strokeStyle: StrokeStyle;
  roundness: Roundness | null;
  roughness: number;
  opacity: number;
  seed: number;
  version: number;
  versionNonce: number;
  index: string | null;
  isDeleted: boolean;
  groupIds: string[];
  frameId: string | null;
  boundElements: BoundElement[] | null;
  updated: number;
  link: string | null;
  locked: boolean;
  customData?: Record<string, JSONValue>;
}

export interface TextProps {
  fontSize: number;
  fontFamily: number;
  text: string;
  textAlign: TextAlign;
  verticalAlign: VerticalAlign;
  containerId: string | null;
  originalText: string;
  autoResize: boolean;
  lineHeight: number;
}

export interface FreedrawProps {
  points: LocalPoint[];
  pressures: number[];
  simulatePressure: boolean;
}

export interface LinearProps {
  points: LocalPoint[];
  startBinding: FixedPointBinding | null;
  endBinding: FixedPointBinding | null;
  startArrowhead: Arrowhead | null;
  endArrowhead: Arrowhead | null;
  polygon: boolean;
}

export interface ArrowProps {
  points: LocalPoint[];
  startBinding: FixedPointBinding | null;
  endBinding: FixedPointBinding | null;
  startArrowhead: Arrowhead | null;
  endArrowhead: Arrowhead | null;
  elbowed: boolean;
  fixedSegments?: FixedSegment[];
  startIsSpecial?: boolean;
  endIsSpecial?: boolean;
}

export interface ImageProps {
  fileId: string | null;
  status: ImageStatus;
  scale: LocalPoint;
  crop: ImageCrop | null;
}

type GenericType = "selection" | "rectangle" | "diamond" | "ellipse" | "embeddable" | "iframe";

export type GenericElement = BaseProperties & { type: GenericType };
export type TextElement = BaseProperties & { type: "text" } & TextProps;
export type FreedrawElement = BaseProperties & { type: "freedraw" } & FreedrawProps;
export type LinearElement = BaseProperties & { type: "line" } & LinearProps;
export type ArrowElement = BaseProperties & { type: "arrow" } & ArrowProps;
export type ImageElement = BaseProperties & { type: "image" } & ImageProps;
export type FrameElement = BaseProperties & { type: "frame" | "magicframe"; name: string | null };

/**
 * A single Excalidraw element: the flat `.excalidraw` object shape where base
 * and type-specific fields live side by side under a `type` discriminator.
 * (parity: ExcalidrawElement.swift)
 */
export type ExcalidrawElement =
  | GenericElement
  | TextElement
  | FreedrawElement
  | LinearElement
  | ArrowElement
  | ImageElement
  | FrameElement;

/** Default base properties for a new element. */
export function defaultBase(id: string, overrides: Partial<BaseProperties> = {}): BaseProperties {
  return {
    id,
    x: 0,
    y: 0,
    width: 0,
    height: 0,
    angle: 0,
    strokeColor: "#1e1e1e",
    backgroundColor: "transparent",
    fillStyle: "solid",
    strokeWidth: 2,
    strokeStyle: "solid",
    roundness: null,
    roughness: 1,
    opacity: 100,
    seed: 1,
    version: 1,
    versionNonce: 0,
    index: null,
    isDeleted: false,
    groupIds: [],
    frameId: null,
    boundElements: null,
    updated: 0,
    link: null,
    locked: false,
    ...overrides,
  };
}

export function defaultTextProps(overrides: Partial<TextProps> = {}): TextProps {
  return {
    fontSize: 20,
    fontFamily: FontFamily.default,
    text: "",
    textAlign: "left",
    verticalAlign: "top",
    containerId: null,
    originalText: "",
    autoResize: true,
    lineHeight: 1.25,
    ...overrides,
  };
}
