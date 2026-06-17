/** The active editing tool. (parity: Tool.swift) */
export type Tool =
  | "selection"
  | "rectangle"
  | "diamond"
  | "ellipse"
  | "line"
  | "arrow"
  | "freedraw"
  | "text"
  | "postit"
  | "table"
  | "frame"
  | "eraser"
  | "laser"
  | "hand";

/** The element type a shape tool creates, or `null` for non-creating tools. */
export function toolElementType(tool: Tool): string | null {
  switch (tool) {
    case "rectangle":
      return "rectangle";
    case "diamond":
      return "diamond";
    case "ellipse":
      return "ellipse";
    case "line":
      return "line";
    case "arrow":
      return "arrow";
    case "freedraw":
      return "freedraw";
    case "frame":
      return "frame";
    default:
      return null;
  }
}

export function isShapeTool(tool: Tool): boolean {
  return toolElementType(tool) !== null;
}
