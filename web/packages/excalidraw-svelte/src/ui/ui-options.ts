// Public configuration for the embeddable editor's chrome. Every field defaults
// to *enabled*, so `<Excalidraw />` with no props is the full editor; a client
// switches pieces off (or narrows the toolbar) without forking the UI.
import type { Tool } from "../editor/index.js";

export interface MenuOptions {
  open?: boolean;
  save?: boolean;
  export?: boolean;
  reset?: boolean;
  theme?: boolean;
  help?: boolean;
}

export interface ContextMenuOptions {
  clipboard?: boolean; // cut/copy/paste
  copyAsImage?: boolean; // copy as PNG/SVG
  styles?: boolean; // copy/paste styles
  frame?: boolean; // wrap in frame
  shapeRecognition?: boolean; // snap to shape
  duplicate?: boolean;
  grouping?: boolean;
  zOrder?: boolean;
  flip?: boolean;
  link?: boolean;
  lock?: boolean;
  deletion?: boolean;
}

export interface ToolbarOptions {
  /** Which tools appear, in order. Defaults to the full set. */
  tools?: Tool[];
  /** The "keep tool active" lock toggle. */
  lock?: boolean;
  /** The image button. */
  image?: boolean;
  /** The "more tools" dropdown (frame, laser, generators). */
  more?: boolean;
}

export interface GeneratorOptions {
  note?: boolean;
  table?: boolean;
  chart?: boolean;
  mermaid?: boolean;
}

export interface UIOptions {
  toolbar?: boolean | ToolbarOptions;
  panel?: boolean;
  menu?: boolean | MenuOptions;
  contextMenu?: boolean | ContextMenuOptions;
  palette?: boolean;
  welcome?: boolean;
  help?: boolean;
  zoomIsland?: boolean;
  undoIsland?: boolean;
  viewIsland?: boolean; // grid / snap / zen toggles
  quickArrows?: boolean;
  generators?: boolean | GeneratorOptions;
  quickActions?: boolean; // bottom-right theme/export/save
}

/** The fully-resolved options the component renders against. */
export interface ResolvedUIOptions {
  toolbar: false | Required<ToolbarOptions>;
  panel: boolean;
  menu: false | Required<MenuOptions>;
  contextMenu: false | Required<ContextMenuOptions>;
  palette: boolean;
  welcome: boolean;
  help: boolean;
  zoomIsland: boolean;
  undoIsland: boolean;
  viewIsland: boolean;
  quickArrows: boolean;
  generators: false | Required<GeneratorOptions>;
  quickActions: boolean;
}

export const ALL_TOOLS: Tool[] = [
  "hand",
  "selection",
  "rectangle",
  "diamond",
  "ellipse",
  "arrow",
  "line",
  "freedraw",
  "text",
  "eraser",
];

const defaultToolbar: Required<ToolbarOptions> = {
  tools: ALL_TOOLS,
  lock: true,
  image: true,
  more: true,
};
const defaultMenu: Required<MenuOptions> = {
  open: true,
  save: true,
  export: true,
  reset: true,
  theme: true,
  help: true,
};
const defaultContextMenu: Required<ContextMenuOptions> = {
  clipboard: true,
  copyAsImage: true,
  styles: true,
  frame: true,
  shapeRecognition: true,
  duplicate: true,
  grouping: true,
  zOrder: true,
  flip: true,
  link: true,
  lock: true,
  deletion: true,
};
const defaultGenerators: Required<GeneratorOptions> = {
  note: true,
  table: true,
  chart: true,
  mermaid: true,
};

/** Everything on — the reference editor. */
export const defaultUIOptions: ResolvedUIOptions = {
  toolbar: defaultToolbar,
  panel: true,
  menu: defaultMenu,
  contextMenu: defaultContextMenu,
  palette: true,
  welcome: true,
  help: true,
  zoomIsland: true,
  undoIsland: true,
  viewIsland: true,
  quickArrows: true,
  generators: defaultGenerators,
  quickActions: true,
};

/** `false` disables a section entirely; an object overrides individual fields. */
function section<T extends object>(
  value: boolean | T | undefined,
  defaults: Required<T>,
): false | Required<T> {
  if (value === false) return false;
  if (value === undefined || value === true) return defaults;
  return { ...defaults, ...value };
}

/** Merge a client's `uiOptions` over the defaults (everything on). */
export function resolveUIOptions(options: UIOptions = {}): ResolvedUIOptions {
  return {
    toolbar: section(options.toolbar, defaultToolbar),
    panel: options.panel ?? true,
    menu: section(options.menu, defaultMenu),
    contextMenu: section(options.contextMenu, defaultContextMenu),
    palette: options.palette ?? true,
    welcome: options.welcome ?? true,
    help: options.help ?? true,
    zoomIsland: options.zoomIsland ?? true,
    undoIsland: options.undoIsland ?? true,
    viewIsland: options.viewIsland ?? true,
    quickArrows: options.quickArrows ?? true,
    generators: section(options.generators, defaultGenerators),
    quickActions: options.quickActions ?? true,
  };
}
