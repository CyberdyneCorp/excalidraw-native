// String-valued enums from the .excalidraw schema. (parity: Enums.swift)

/** Fill pattern for shape backgrounds (`FillStyle`). */
export type FillStyle = "hachure" | "cross-hatch" | "solid" | "zigzag";

/** Stroke line style (`StrokeStyle`). */
export type StrokeStyle = "solid" | "dashed" | "dotted";

/** Horizontal text alignment (`TEXT_ALIGN`). */
export type TextAlign = "left" | "center" | "right";

/** Vertical text alignment (`VERTICAL_ALIGN`). */
export type VerticalAlign = "top" | "middle" | "bottom";

/** Image persistence status (`ExcalidrawImageElement.status`). */
export type ImageStatus = "pending" | "saved" | "error";

/** Binding containment mode (`BindMode`). */
export type BindMode = "inside" | "orbit" | "skip";

/**
 * Arrowhead styles, including legacy values still present in older files. Stored
 * as the raw string so unknown/future ids round-trip losslessly.
 */
export type Arrowhead =
  | "arrow"
  | "bar"
  | "circle"
  | "circle_outline"
  | "triangle"
  | "triangle_outline"
  | "diamond"
  | "diamond_outline"
  | "cardinality_one"
  | "cardinality_many"
  | "cardinality_one_or_many"
  | "cardinality_exactly_one"
  | "cardinality_zero_or_one"
  | "cardinality_zero_or_many"
  | "dot"
  | "crowfoot_one"
  | "crowfoot_many"
  | "crowfoot_one_or_many";

/** The element/tool types supported by Excalidraw (`ElementType`). */
export type ElementType =
  | "selection"
  | "rectangle"
  | "diamond"
  | "ellipse"
  | "arrow"
  | "line"
  | "freedraw"
  | "text"
  | "image"
  | "frame"
  | "magicframe"
  | "embeddable"
  | "iframe";

/**
 * Font family ids are stored as integers in the file. Stable known values from
 * upstream `FONT_FAMILY`; kept open (number) so unknown ids round-trip.
 */
export const FontFamily = {
  virgil: 1,
  helvetica: 2,
  cascadia: 3,
  excalifont: 5,
  nunito: 6,
  lilitaOne: 7,
  comicShanns: 8,
  liberationSans: 9,
  assistant: 10,
  /** Default for new text (`DEFAULT_FONT_FAMILY` = Excalifont). */
  default: 5,
} as const;

/** Roundness types (`ROUNDNESS`). Stored as an integer in `roundness.type`. */
export const RoundnessType = {
  legacy: 1,
  proportionalRadius: 2,
  adaptiveRadius: 3,
} as const;

/** `.excalidraw` schema constants (`ExcalidrawSchema`). */
export const ExcalidrawSchema = {
  schemaVersion: 2,
  fileType: "excalidraw",
} as const;
