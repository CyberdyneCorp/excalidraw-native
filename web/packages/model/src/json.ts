/**
 * Canonical JSON: recursively sort object keys, then stringify with 2-space
 * indentation — mirroring Swift's `JSONEncoder` with `.sortedKeys`. Used so the
 * TypeScript and Swift twins produce semantically identical output and the
 * encode→decode→encode round-trip is a fixed point.
 */
export function canonicalize(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value !== null && typeof value === "object") {
    const source = value as Record<string, unknown>;
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(source).sort()) {
      if (source[key] !== undefined) out[key] = canonicalize(source[key]);
    }
    return out;
  }
  return value;
}

export function canonicalJSON(value: unknown, prettyPrinted = true): string {
  return JSON.stringify(canonicalize(value), null, prettyPrinted ? 2 : undefined);
}

/** Semantic JSON equality, ignoring key order and formatting. */
export function semanticEqual(a: unknown, b: unknown): boolean {
  return canonicalJSON(a, false) === canonicalJSON(b, false);
}
