import { readFileSync } from "node:fs";
import { join } from "node:path";

/**
 * Read a shared golden fixture from the repo-root `Fixtures/` directory — the
 * SAME files the Swift `XCTest` suite reads, so the two implementations are
 * checked against one source of truth. Vitest runs with cwd = `web/`.
 */
export function fixture(name: string): string {
  return readFileSync(join(process.cwd(), "..", "Fixtures", name), "utf8");
}
