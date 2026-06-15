// Generates rough.js reference output used by RoughKit's parity tests
// (Tests/RoughKitTests/RoughJSParityTests.swift).
//
// rough.js is not a dependency of this repo; point ROUGH at a local install:
//   ROUGH=/path/to/node_modules/roughjs node scripts/rough_ref.cjs
//
// Captured against rough.js 4.6.6 (Excalidraw uses 4.6.4 — same algorithm).
// Defaults match RoughKit's RoughOptions; a fixed non-zero seed is required
// because rough.js falls back to Math.random() for seed 0.

const path = process.env.ROUGH || "roughjs";
const rough = require(require("path").join(path, "bundled/rough.cjs.js"));
const gen = rough.generator();

function dump(name, drawable) {
  const sets = drawable.sets.map((s) => ({
    type: s.type,
    ops: s.ops.map((o) => ({ op: o.op, data: o.data.map((n) => Math.round(n * 1e6) / 1e6) })),
  }));
  console.log("### " + name);
  console.log(JSON.stringify(sets));
}

dump("line_seed1", gen.line(0, 0, 100, 0, { seed: 1 }));
dump("rect_seed1", gen.rectangle(0, 0, 100, 50, { seed: 1 }));
dump("ellipse_seed1", gen.ellipse(50, 30, 100, 60, { seed: 1 }));
dump("filled_rect_seed1", gen.rectangle(0, 0, 40, 40, { seed: 1, fill: "#f00", fillStyle: "hachure" }));
