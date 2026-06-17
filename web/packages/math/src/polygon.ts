import { PRECISION, type Point } from "./point.js";
import { LineSegment } from "./segment.js";

/**
 * A closed polygon. The stored `points` are closed: the first point is repeated
 * as the last when needed. (parity: Polygon.swift)
 */
export class Polygon {
  readonly points: Point[];

  constructor(points: Point[]) {
    this.points = Polygon.closed(points);
  }

  private static closed(points: Point[]): Point[] {
    const first = points[0];
    const last = points[points.length - 1];
    if (first === undefined || last === undefined) return points;
    return first.isApproximatelyEqual(last) ? points : [...points, first];
  }

  /** Even-odd ray-casting containment test (`polygonIncludesPoint`). */
  includes(point: Point): boolean {
    const { x, y } = point;
    let inside = false;
    let j = this.points.length - 1;
    for (let i = 0; i < this.points.length; i++) {
      const pi = this.points[i]!;
      const pj = this.points[j]!;
      const xi = pi.x;
      const yi = pi.y;
      const xj = pj.x;
      const yj = pj.y;
      if (
        ((yi > y && yj <= y) || (yi <= y && yj > y)) &&
        x < ((xj - xi) * (y - yi)) / (yj - yi) + xi
      ) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  /** Non-zero winding-number containment test (`polygonIncludesPointNonZero`). */
  includesNonZero(point: Point): boolean {
    const { x, y } = point;
    let winding = 0;
    for (let i = 0; i < this.points.length; i++) {
      const jdx = (i + 1) % this.points.length;
      const pi = this.points[i]!;
      const pj = this.points[jdx]!;
      const xi = pi.x;
      const yi = pi.y;
      const xj = pj.x;
      const yj = pj.y;
      if (yi <= y) {
        if (yj > y && (xj - xi) * (y - yi) - (x - xi) * (yj - yi) > 0) {
          winding += 1;
        }
      } else if (yj <= y && (xj - xi) * (y - yi) - (x - xi) * (yj - yi) < 0) {
        winding -= 1;
      }
    }
    return winding !== 0;
  }

  /** Whether `point` lies on any edge within `threshold` (`pointOnPolygon`). */
  contains(point: Point, threshold = PRECISION): boolean {
    if (this.points.length < 2) return false;
    for (let i = 0; i < this.points.length - 1; i++) {
      if (new LineSegment(this.points[i]!, this.points[i + 1]!).contains(point, threshold)) {
        return true;
      }
    }
    return false;
  }
}
