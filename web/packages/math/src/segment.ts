import { Line } from "./line.js";
import { PRECISION, Point } from "./point.js";
import { Vector } from "./vector.js";

/** A bounded line segment between two endpoints. (parity: LineSegment.swift) */
export class LineSegment {
  constructor(
    public a: Point,
    public b: Point,
  ) {}

  /** Rotate about `origin` (defaults to its midpoint) (`lineSegmentRotate`). */
  rotated(angle: number, origin?: Point): LineSegment {
    const center = origin ?? this.a.midpoint(this.b);
    return new LineSegment(this.a.rotated(center, angle), this.b.rotated(center, angle));
  }

  /** Shortest distance from `point` to the segment (`distanceToLineSegment`). */
  distanceToPoint(point: Point): number {
    const aToP = new Vector(point.x - this.a.x, point.y - this.a.y);
    const aToB = new Vector(this.b.x - this.a.x, this.b.y - this.a.y);
    const lenSq = aToB.magnitudeSquared;
    let param = -1;
    if (lenSq !== 0) param = aToP.dot(aToB) / lenSq;

    let closest: Point;
    if (param < 0) {
      closest = this.a;
    } else if (param > 1) {
      closest = this.b;
    } else {
      closest = new Point(this.a.x + param * aToB.u, this.a.y + param * aToB.v);
    }
    return point.distance(closest);
  }

  /** Whether `point` lies on the segment within `threshold` (`pointOnLineSegment`). */
  contains(point: Point, threshold = PRECISION): boolean {
    const d = this.distanceToPoint(point);
    return d === 0 || d < threshold;
  }

  /**
   * Intersection of two segments, or `null` (`segmentsIntersectAt`). Preserves
   * upstream's half-open `[0, 1)` parameter ranges.
   */
  intersection(other: LineSegment): Point | null {
    const a0 = Vector.fromPoint(this.a);
    const a1 = Vector.fromPoint(this.b);
    const b0 = Vector.fromPoint(other.a);
    const b1 = Vector.fromPoint(other.b);
    const r = a1.sub(a0);
    const s = b1.sub(b0);
    const denominator = r.cross(s);
    if (denominator === 0) return null;

    const i = b0.sub(a0);
    const u = i.cross(r) / denominator;
    const t = i.cross(s) / denominator;
    if (u === 0) return null;

    if (t >= 0 && t < 1 && u >= 0 && u < 1) {
      return a0.add(r.scaled(t)).point();
    }
    return null;
  }

  /**
   * Intersection treating both segments as the lines through their endpoints,
   * but only returning a point that lies on both segments
   * (`lineSegmentIntersectionPoints`).
   */
  lineIntersection(other: LineSegment, threshold = PRECISION): Point | null {
    const candidate = new Line(this.a, this.b).intersection(new Line(other.a, other.b));
    if (candidate === null) return null;
    if (!other.contains(candidate, threshold) || !this.contains(candidate, threshold)) {
      return null;
    }
    return candidate;
  }

  /** Shortest distance between two segments (`lineSegmentsDistance`). */
  distanceToSegment(other: LineSegment): number {
    if (this.lineIntersection(other) !== null) return 0;
    return Math.min(
      other.distanceToPoint(this.a),
      other.distanceToPoint(this.b),
      this.distanceToPoint(other.a),
      this.distanceToPoint(other.b),
    );
  }
}
