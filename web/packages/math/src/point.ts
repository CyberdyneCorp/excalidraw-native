import { Vector } from "./vector.js";

/**
 * Numerical tolerance used throughout geometry, matching upstream `PRECISION`
 * (`10e-5`, i.e. `1e-4`). (parity: ExcalidrawMath.precision)
 */
export const PRECISION = 10e-5;

/**
 * A 2D point in scene coordinates. Wire form is the JSON array `[x, y]`, to
 * match the `.excalidraw` format (points, scale, fixedPoint, fixedSegment).
 * (parity: Sources/ExcalidrawMath/Point.swift)
 */
export class Point {
  constructor(
    public x: number,
    public y: number,
  ) {}

  static readonly zero = new Point(0, 0);

  /** Euclidean distance to another point. */
  distance(other: Point): number {
    return this.sub(other).magnitude;
  }

  /** Magnitude treating the point as a vector from the origin. */
  get magnitude(): number {
    return Math.sqrt(this.x * this.x + this.y * this.y);
  }

  add(other: Point): Point {
    return new Point(this.x + other.x, this.y + other.y);
  }

  sub(other: Point): Point {
    return new Point(this.x - other.x, this.y - other.y);
  }

  /** Rotate around `center` by `angle` radians (`pointRotateRads`). */
  rotated(center: Point, angle: number): Point {
    if (angle === 0) return this;
    const dx = this.x - center.x;
    const dy = this.y - center.y;
    return new Point(
      dx * Math.cos(angle) - dy * Math.sin(angle) + center.x,
      dx * Math.sin(angle) + dy * Math.cos(angle) + center.y,
    );
  }

  /** Translate by a vector (`pointTranslate`). */
  translated(v: Vector): Point {
    return new Point(this.x + v.u, this.y + v.v);
  }

  /** Midpoint between this and `other` (`pointCenter`). */
  midpoint(other: Point): Point {
    return new Point((this.x + other.x) / 2, (this.y + other.y) / 2);
  }

  /** Squared Euclidean distance — avoids a `sqrt` (`pointDistanceSq`). */
  distanceSquared(other: Point): number {
    const dx = other.x - this.x;
    const dy = other.y - this.y;
    return dx * dx + dy * dy;
  }

  /** Scale away from `origin` by `multiplier` (`pointScaleFromOrigin`). */
  scaledFrom(origin: Point, multiplier: number): Point {
    return origin.translated(Vector.fromPoint(this, origin).scaled(multiplier));
  }

  /** Whether this lies within the AABB bounded by `a` and `b`. */
  isWithin(a: Point, b: Point): boolean {
    return (
      this.x <= Math.max(a.x, b.x) &&
      this.x >= Math.min(a.x, b.x) &&
      this.y <= Math.max(a.y, b.y) &&
      this.y >= Math.min(a.y, b.y)
    );
  }

  /** Coordinate-wise comparison within `tolerance` (`pointsEqual`). */
  isApproximatelyEqual(other: Point, tolerance = PRECISION): boolean {
    return Math.abs(this.x - other.x) < tolerance && Math.abs(this.y - other.y) < tolerance;
  }

  /** Exact equality. */
  equals(other: Point): boolean {
    return this.x === other.x && this.y === other.y;
  }

  /** Wire form `[x, y]`. */
  toArray(): [number, number] {
    return [this.x, this.y];
  }

  static fromArray([x, y]: readonly [number, number]): Point {
    return new Point(x, y);
  }
}
