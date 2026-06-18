import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * The canonical core must take NO Yjs dependency — the adapter is additive and
 * optional (issue #11). vitest cwd is web/.
 */
describe("no core coupling", () => {
  const coreDir = join(process.cwd(), "packages/excalidraw-svelte");

  it("the core package.json declares no yjs dependency (any kind)", () => {
    const pkg = JSON.parse(readFileSync(join(coreDir, "package.json"), "utf8"));
    const all = {
      ...pkg.dependencies,
      ...pkg.devDependencies,
      ...pkg.peerDependencies,
      ...pkg.optionalDependencies,
    };
    expect(Object.keys(all)).not.toContain("yjs");
  });

  it("the built core does not import yjs", () => {
    // The collaboration entrypoint is where the editor hooks live.
    const dist = readFileSync(join(coreDir, "dist/svelte/editor-store.js"), "utf8");
    expect(dist).not.toMatch(/["']yjs["']/);
  });
});
