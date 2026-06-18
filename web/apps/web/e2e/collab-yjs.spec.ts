import { type Page, expect, test } from "@playwright/test";
import { drag, read, ready } from "./helpers.js";

/**
 * The optional Yjs/CRDT backend, end-to-end in real browsers: two pages join one
 * room through a same-origin BroadcastChannel provider (no relay), draw, and
 * converge; a reload re-hydrates from the live peer; and a Yjs-synced scene
 * round-trips `.excalidraw` into the canonical LWW/solo editor. BroadcastChannel
 * is shared only within one browser context, so both peers live in one context.
 */
async function joinYjs(page: Page, room: string, name: string): Promise<void> {
  await page.goto(`/?yjs=${room}&name=${name}`);
  await ready(page);
  await page.waitForFunction(() => (window as unknown as { __yjs?: unknown }).__yjs !== undefined);
}

/** Wait until the editor's scene contains an element of `type` (arg passed into
 * the browser — a serialized page function can't close over outer variables). */
function waitForType(page: Page, type: string): Promise<unknown> {
  return page.waitForFunction((t) => {
    const store = (window as unknown as { __store?: { scene: { visibleElements: { type: string }[] } } })
      .__store;
    return store?.scene.visibleElements.some((e) => e.type === t) ?? false;
  }, type);
}

test("two browsers in one Yjs room converge — CRDT, no relay", async ({ browser }) => {
  const context = await browser.newContext(); // shared context → shared BroadcastChannel
  const room = "e2e-yjs";
  const alice = await context.newPage();
  const bob = await context.newPage();
  await joinYjs(alice, room, "Alice");
  await joinYjs(bob, room, "Bob");

  // Alice draws a rectangle → Bob converges via the CRDT.
  await alice.getByTestId("tool-rectangle").click();
  await drag(alice, { x: 0.3, y: 0.3 }, { x: 0.5, y: 0.5 });
  await waitForType(bob, "rectangle");

  // Bob draws an ellipse → Alice converges. Both scenes now match.
  await bob.getByTestId("tool-ellipse").click();
  await drag(bob, { x: 0.55, y: 0.3 }, { x: 0.75, y: 0.5 });
  await waitForType(alice, "ellipse");

  const aliceTypes = await read(alice, (s) => s.scene.visibleElements.map((e) => e.type).sort());
  const bobTypes = await read(bob, (s) => s.scene.visibleElements.map((e) => e.type).sort());
  expect(aliceTypes).toEqual(["ellipse", "rectangle"]);
  expect(bobTypes).toEqual(["ellipse", "rectangle"]);

  // Reload re-hydrates from the live peer (BroadcastChannel state sync).
  await bob.reload();
  await ready(bob);
  await bob.waitForFunction(() => {
    const store = (window as unknown as { __store?: { scene: { visibleElements: unknown[] } } }).__store;
    return (store?.scene.visibleElements.length ?? 0) === 2;
  });

  await alice.screenshot({ path: "test-results/screens/15-collab-yjs.png" });
  await context.close();
});

test("remote cursors propagate via Yjs awareness", async ({ browser }) => {
  const context = await browser.newContext();
  const alice = await context.newPage();
  const bob = await context.newPage();
  await joinYjs(alice, "e2e-yjs-presence", "Alice");
  await joinYjs(bob, "e2e-yjs-presence", "Bob");

  // Alice moves her cursor over the canvas → trackPointer → Yjs awareness.
  const box = await alice.getByTestId("canvas").boundingBox();
  if (box === null) throw new Error("canvas not found");
  await alice.mouse.move(box.x + box.width * 0.4, box.y + box.height * 0.4);
  await alice.mouse.move(box.x + box.width * 0.45, box.y + box.height * 0.45);

  // Bob sees Alice's presence (with a cursor) and an overlay cursor for her.
  await bob.waitForFunction(() => {
    const collab = (window as unknown as { __yjs?: { collab: { remotePresences(): { peer: { name: string }; pointer: unknown }[] } } }).__yjs?.collab;
    return (collab?.remotePresences() ?? []).some((p) => p.peer.name === "Alice" && p.pointer !== null);
  });
  await bob.waitForFunction(() => {
    const store = (window as unknown as { __store?: { externalCursors: unknown[] } }).__store;
    return (store?.externalCursors.length ?? 0) > 0;
  });

  await context.close();
});

test("a Yjs-synced scene round-trips .excalidraw into the LWW/solo editor", async ({ browser }) => {
  const context = await browser.newContext();
  const yjsPage = await context.newPage();
  await joinYjs(yjsPage, "e2e-yjs-fidelity", "Y");
  await yjsPage.getByTestId("tool-rectangle").click();
  await drag(yjsPage, { x: 0.3, y: 0.3 }, { x: 0.5, y: 0.5 });
  await waitForType(yjsPage, "rectangle");

  // Export the Yjs-produced scene to `.excalidraw`.
  const json = await yjsPage.evaluate(() =>
    (window as unknown as { __store: { documentJSON(): string } }).__store.documentJSON(),
  );

  // Load it into a fresh solo (canonical LWW) editor — proves the adapter didn't
  // fork the model: a Yjs scene is a valid `.excalidraw` the core reads back.
  const solo = await context.newPage();
  await solo.goto("/");
  await ready(solo);
  await solo.evaluate(
    (j) => (window as unknown as { __store: { loadDocument(s: string): void } }).__store.loadDocument(j),
    json,
  );
  const soloTypes = await read(solo, (s) => s.scene.visibleElements.map((e) => e.type).sort());
  expect(soloTypes).toEqual(["rectangle"]);

  await context.close();
});
