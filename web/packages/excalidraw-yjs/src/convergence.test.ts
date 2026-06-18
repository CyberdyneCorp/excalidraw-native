import { describe, expect, it } from "vitest";
import * as Y from "yjs";
import { readDocElements } from "./mapping.js";
import {
  applyEdit,
  edit,
  elementsKey,
  exchange,
  rect,
  seed,
  stripUpdated,
} from "./test-helpers.js";

/** Snapshot a doc's scene for structural comparison (ignoring `updated`). */
function scene(doc: Y.Doc): Record<string, unknown>[] {
  return readDocElements(elementsKey(doc)).map(stripUpdated);
}

describe("Yjs convergence", () => {
  it("disjoint edits to different elements converge — in BOTH apply orders", () => {
    const base = [rect("a", { index: "a0" }), rect("b", { index: "a1" })];

    // Order 1: apply A's update into B, then B's into A.
    const a1 = seed(base);
    const b1 = new Y.Doc();
    Y.applyUpdate(b1, Y.encodeStateAsUpdate(a1));
    applyEdit(a1, [edit(base[0]!, { x: 111 }), base[1]!]);
    applyEdit(b1, [base[0]!, edit(base[1]!, { y: 222 })]);
    exchange(a1, b1);

    // Order 2: same edits, reversed exchange.
    const a2 = seed(base);
    const b2 = new Y.Doc();
    Y.applyUpdate(b2, Y.encodeStateAsUpdate(a2));
    applyEdit(a2, [edit(base[0]!, { x: 111 }), base[1]!]);
    applyEdit(b2, [base[0]!, edit(base[1]!, { y: 222 })]);
    exchange(b2, a2);

    expect(scene(a1)).toEqual(scene(b1)); // commutative within order 1
    expect(scene(a2)).toEqual(scene(b2)); // commutative within order 2
    expect(scene(a1)).toEqual(scene(a2)); // both orders reach the same scene
  });

  it("FIELD-LEVEL MERGE: concurrent recolor + move both survive (the LWW-loses case)", () => {
    const x = rect("x", { index: "a0", strokeColor: "#000000", x: 0 });
    const a = seed([x]);
    const b = new Y.Doc();
    Y.applyUpdate(b, Y.encodeStateAsUpdate(a));

    applyEdit(a, [edit(x, { strokeColor: "#ff0000" })]); // peer A recolors
    applyEdit(b, [edit(x, { x: 500 })]); // peer B moves, concurrently
    exchange(a, b);

    const merged = readDocElements(elementsKey(a)).find((e) => e.id === "x");
    expect(merged?.strokeColor).toBe("#ff0000"); // recolor survived
    expect(merged?.x).toBe(500); // move survived too — LWW would have lost one
    expect(scene(a)).toEqual(scene(b));
  });

  it("soft-delete vs concurrent edit converges to a tombstone (no hard removal)", () => {
    const x = rect("x", { index: "a0" });
    const a = seed([x]);
    const b = new Y.Doc();
    Y.applyUpdate(b, Y.encodeStateAsUpdate(a));

    applyEdit(a, []); // peer A deletes x (drops it → tombstone)
    applyEdit(b, [edit(x, { x: 300 })]); // peer B edits x concurrently
    exchange(a, b);

    expect([...elementsKey(a).keys()]).toEqual(["x"]); // entry still present
    const merged = readDocElements(elementsKey(a)).find((e) => e.id === "x");
    expect(merged?.isDeleted).toBe(true); // delete wins
    expect(scene(a)).toEqual(scene(b));
  });

  it("concurrent inserts converge to a stable order driven by index", () => {
    const a = seed([rect("a", { index: "a0" }), rect("z", { index: "a3" })]);
    const b = new Y.Doc();
    Y.applyUpdate(b, Y.encodeStateAsUpdate(a));

    applyEdit(a, [
      rect("a", { index: "a0" }),
      rect("m", { index: "a1" }),
      rect("z", { index: "a3" }),
    ]);
    applyEdit(b, [
      rect("a", { index: "a0" }),
      rect("p", { index: "a2" }),
      rect("z", { index: "a3" }),
    ]);
    exchange(a, b);

    expect(readDocElements(elementsKey(a)).map((e) => e.id)).toEqual(["a", "m", "p", "z"]);
    expect(scene(a)).toEqual(scene(b));
  });
});
