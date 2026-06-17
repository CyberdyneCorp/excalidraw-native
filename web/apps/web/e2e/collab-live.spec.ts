import { expect, test } from "@playwright/test";
import { drag, read, ready, shot } from "./helpers.js";

/**
 * The web half of the live iPad↔browser session. It joins a room on an
 * *external* relay (started by `scripts/collab-live.sh`), draws an element, and
 * waits to receive the iOS app's element — proving the real browser app and the
 * real simulator app share one scene. Skipped unless `XS_RELAY` + `XS_ROOM` are
 * set, and given a long timeout since it waits for the simulator app to build,
 * launch, and draw.
 */
const RELAY = process.env.XS_RELAY;
const ROOM = process.env.XS_ROOM;

test.skip(!RELAY || !ROOM, "set XS_RELAY / XS_ROOM (run via scripts/collab-live.sh)");

test("browser shares one room with the iOS app", async ({ page }) => {
  test.setTimeout(720_000); // waits for a cold xcodebuild + simulator launch

  await page.goto(`/?relay=${encodeURIComponent(RELAY!)}&room=${ROOM}&name=web`);
  await ready(page);
  await page.waitForFunction(() => {
    const store = (window as unknown as { __store?: { collab?: { you: string | null } | null } }).__store;
    return store?.collab?.you != null;
  });

  // Draw a rectangle → broadcast to the room (and seed the relay snapshot for
  // the iPad's late join).
  await selectThenDraw(page);
  await expect
    .poll(() => read(page, (s) => s.scene.visibleElements.some((e) => e.id.startsWith("web"))), {
      timeout: 10_000,
    })
    .toBe(true);

  // Wait until the iPad's element arrives (id namespaced by its peer id "ipad-").
  await expect
    .poll(
      () => read(page, (s) => s.scene.visibleElements.some((e) => e.id.startsWith("ipad"))),
      { timeout: 660_000, intervals: [1000] },
    )
    .toBe(true);

  // Both peers' elements are present; a peer (the iPad) is in the roster.
  const summary = await read(page, (s) => ({
    web: s.scene.visibleElements.filter((e) => e.id.startsWith("web")).length,
    ipad: s.scene.visibleElements.filter((e) => e.id.startsWith("ipad")).length,
    peers: s.collab === null ? 0 : s.collab.peers.size,
  }));
  expect(summary.web).toBeGreaterThan(0);
  expect(summary.ipad).toBeGreaterThan(0);
  expect(summary.peers).toBeGreaterThan(0);
  await shot(page, "15-collab-live-browser");

  // Stay connected briefly so the iPad still sees us in its roster while it
  // checks presence and captures its screenshot (avoids a peer-left race).
  await page.waitForTimeout(8000);
});

async function selectThenDraw(page: import("@playwright/test").Page): Promise<void> {
  await page.getByTestId("tool-rectangle").click();
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.55, y: 0.55 });
}
