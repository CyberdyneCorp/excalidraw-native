import type { Point } from "./point.js";

/** A triangle defined by three points. (parity: Triangle.swift) */
export class Triangle {
  constructor(
    public a: Point,
    public b: Point,
    public c: Point,
  ) {}

  /**
   * Whether `p` lies inside the triangle. Returns `false` for points strictly
   * outside; points on an edge are treated as inside (`triangleIncludesPoint`).
   */
  includes(p: Point): boolean {
    const sign = (p1: Point, p2: Point, p3: Point): number =>
      (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
    const d1 = sign(p, this.a, this.b);
    const d2 = sign(p, this.b, this.c);
    const d3 = sign(p, this.c, this.a);
    const hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
    const hasPos = d1 > 0 || d2 > 0 || d3 > 0;
    return !(hasNeg && hasPos);
  }
}
