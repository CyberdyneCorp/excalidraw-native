import { Point } from "./point.js";

/** An infinite line through two points. (parity: Line.swift) */
export class Line {
  constructor(
    public p: Point,
    public q: Point,
  ) {}

  /** Intersection of two infinite lines, or `null` if parallel (`linesIntersectAt`). */
  intersection(other: Line): Point | null {
    const a1 = this.q.y - this.p.y;
    const b1 = this.p.x - this.q.x;
    const a2 = other.q.y - other.p.y;
    const b2 = other.p.x - other.q.x;
    const d = a1 * b2 - a2 * b1;
    if (d === 0) return null;
    const c1 = a1 * this.p.x + b1 * this.p.y;
    const c2 = a2 * other.p.x + b2 * other.p.y;
    return new Point((c1 * b2 - c2 * b1) / d, (a1 * c2 - a2 * c1) / d);
  }
}
