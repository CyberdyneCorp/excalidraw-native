import type { Line } from "./line.js";
import { PRECISION, Point } from "./point.js";
import type { LineSegment } from "./segment.js";
import { Vector } from "./vector.js";

function signOf(value: number): number {
  return value > 0 ? 1 : value < 0 ? -1 : 0;
}

/** An axis-aligned ellipse given by its center and half-extents. (parity: Ellipse.swift) */
export class Ellipse {
  constructor(
    public center: Point,
    public halfWidth: number,
    public halfHeight: number,
  ) {}

  /** Whether `p` is inside or on the ellipse (`ellipseIncludesPoint`). */
  includes(p: Point): boolean {
    const nx = (p.x - this.center.x) / this.halfWidth;
    const ny = (p.y - this.center.y) / this.halfHeight;
    return nx * nx + ny * ny <= 1;
  }

  /** Whether `p` lies on the outline within `threshold` (`ellipseTouchesPoint`). */
  touches(p: Point, threshold = PRECISION): boolean {
    return this.distance(p) <= threshold;
  }

  /**
   * Shortest distance from `p` to the outline, via three Newton iterations in
   * the first quadrant (`ellipseDistanceFromPoint`).
   */
  distance(p: Point): number {
    const a = this.halfWidth;
    const b = this.halfHeight;
    const translated = Vector.fromPoint(p).sub(Vector.fromPoint(this.center));
    const px = Math.abs(translated.u);
    const py = Math.abs(translated.v);

    let tx = 0.707;
    let ty = 0.707;
    for (let i = 0; i < 3; i++) {
      const x = a * tx;
      const y = b * ty;
      const ex = ((a * a - b * b) * (tx * tx * tx)) / a;
      const ey = ((b * b - a * a) * (ty * ty * ty)) / b;
      const rx = x - ex;
      const ry = y - ey;
      const qx = px - ex;
      const qy = py - ey;
      const r = Math.hypot(ry, rx);
      const q = Math.hypot(qy, qx);
      tx = Math.min(1, Math.max(0, (qx * r) / q / a + ex / a));
      ty = Math.min(1, Math.max(0, (qy * r) / q / b + ey / b));
      const t = Math.hypot(ty, tx);
      tx /= t;
      ty /= t;
    }

    const closest = new Point(a * tx * signOf(translated.u), b * ty * signOf(translated.v));
    return translated.point().distance(closest);
  }

  /** Up to two intersections of a segment with the ellipse (`ellipseSegmentInterceptPoints`). */
  intersectionWithSegment(s: LineSegment): Point[] {
    const rx = this.halfWidth;
    const ry = this.halfHeight;
    const dir = Vector.fromPoint(s.b, s.a);
    const diff = new Vector(s.a.x - this.center.x, s.a.y - this.center.y);
    const mDir = new Vector(dir.u / (rx * rx), dir.v / (ry * ry));
    const mDiff = new Vector(diff.u / (rx * rx), diff.v / (ry * ry));

    const a = dir.dot(mDir);
    const b = dir.dot(mDiff);
    const c = diff.dot(mDiff) - 1;
    const d = b * b - a * c;

    const pointAt = (t: number): Point =>
      new Point(s.a.x + (s.b.x - s.a.x) * t, s.a.y + (s.b.y - s.a.y) * t);

    const result: Point[] = [];
    if (d > 0) {
      const ta = (-b - Math.sqrt(d)) / a;
      const tb = (-b + Math.sqrt(d)) / a;
      if (ta >= 0 && ta <= 1) result.push(pointAt(ta));
      if (tb >= 0 && tb <= 1) result.push(pointAt(tb));
    } else if (d === 0) {
      const t = -b / a;
      if (t >= 0 && t <= 1) result.push(pointAt(t));
    }
    return result;
  }

  /** Intersections of an infinite line with the ellipse (`ellipseLineIntersectionPoints`). */
  intersectionWithLine(line: Line): Point[] {
    const x1 = line.p.x - this.center.x;
    const y1 = line.p.y - this.center.y;
    const x2 = line.q.x - this.center.x;
    const y2 = line.q.y - this.center.y;
    const a = (x2 - x1) ** 2 / this.halfWidth ** 2 + (y2 - y1) ** 2 / this.halfHeight ** 2;
    const b =
      2 * ((x1 * (x2 - x1)) / this.halfWidth ** 2 + (y1 * (y2 - y1)) / this.halfHeight ** 2);
    const c = x1 ** 2 / this.halfWidth ** 2 + y1 ** 2 / this.halfHeight ** 2 - 1;
    const disc = b * b - 4 * a * c;
    const t1 = (-b + Math.sqrt(disc)) / (2 * a);
    const t2 = (-b - Math.sqrt(disc)) / (2 * a);
    const candidates = [
      new Point(x1 + t1 * (x2 - x1) + this.center.x, y1 + t1 * (y2 - y1) + this.center.y),
      new Point(x1 + t2 * (x2 - x1) + this.center.x, y1 + t2 * (y2 - y1) + this.center.y),
    ].filter((p) => !Number.isNaN(p.x) && !Number.isNaN(p.y));

    if (candidates.length === 2 && candidates[0]!.isApproximatelyEqual(candidates[1]!)) {
      return [candidates[0]!];
    }
    return candidates;
  }
}
