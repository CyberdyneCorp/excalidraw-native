import { N24_C_VALUES, N24_T_VALUES } from "./legendre-gauss.js";
import { Point } from "./point.js";
import type { LineSegment } from "./segment.js";
import { Vector } from "./vector.js";

/**
 * A cubic Bézier curve with four control points. Covers point evaluation, the
 * tangent, Legendre–Gauss arc length, length-parameterization, curve↔segment
 * Newton intersection, and closest-point search. (parity: Curve.swift)
 */
export class Curve {
  constructor(
    public p0: Point,
    public p1: Point,
    public p2: Point,
    public p3: Point,
  ) {}

  /** Point on the curve at parameter `t ∈ [0, 1]` (`bezierEquation`). */
  point(t: number): Point {
    const mt = 1 - t;
    const a = mt * mt * mt;
    const b = 3 * mt * mt * t;
    const c = 3 * mt * t * t;
    const d = t * t * t;
    return new Point(
      a * this.p0.x + b * this.p1.x + c * this.p2.x + d * this.p3.x,
      a * this.p0.y + b * this.p1.y + c * this.p2.y + d * this.p3.y,
    );
  }

  /** Tangent vector (the derivative) at parameter `t` (`curveTangent`). */
  tangent(t: number): Vector {
    const mt = 1 - t;
    const component = (a: number, b: number, c: number, d: number): number =>
      -3 * mt * mt * a +
      3 * mt * mt * b -
      6 * t * mt * b -
      3 * t * t * c +
      6 * t * mt * c +
      3 * t * t * d;
    return new Vector(
      component(this.p0.x, this.p1.x, this.p2.x, this.p3.x),
      component(this.p0.y, this.p1.y, this.p2.y, this.p3.y),
    );
  }

  /** Approximate arc length of the whole curve (`curveLength`). */
  get length(): number {
    return this.lengthAt(1);
  }

  /** Arc length from `t = 0` to `t` using 24-point Legendre–Gauss quadrature. */
  lengthAt(t: number): number {
    if (t <= 0) return 0;
    const half = t / 2;
    let sum = 0;
    for (let i = 0; i < 24; i++) {
      const u = half * N24_T_VALUES[i]! + half;
      sum += N24_C_VALUES[i]! * this.tangent(u).magnitude;
    }
    return half * sum;
  }

  /** The point at `percent` (0–1) of the curve's total arc length (`curvePointAtLength`). */
  pointAtLength(percent: number): Point {
    if (percent <= 0) return this.point(0);
    if (percent >= 1) return this.point(1);

    const total = this.length;
    const target = total * percent;
    let tMin = 0;
    let tMax = 1;
    let t = percent;
    const tolerance = total * 0.0001;

    for (let i = 0; i < 20; i++) {
      const current = this.lengthAt(t);
      if (Math.abs(current - target) < tolerance) break;
      if (current < target) tMin = t;
      else tMax = t;
      t = (tMin + tMax) / 2;
    }
    return this.point(t);
  }

  /**
   * Intersection points between this curve and a line segment, solved with
   * Newton's method from a few seed guesses (`curveIntersectLineSegment`).
   */
  intersections(segment: LineSegment, tolerance = 1e-2, iterationLimit = 4): Point[] {
    const seeds: [number, number][] = [
      [0.5, 0],
      [0.2, 0],
      [0.8, 0],
    ];
    for (const [t0, s0] of seeds) {
      const found = this.solve(segment, t0, s0, tolerance, iterationLimit);
      if (found !== null) return [found];
    }
    return [];
  }

  private solve(
    segment: LineSegment,
    t0: number,
    s0: number,
    tolerance: number,
    iterationLimit: number,
  ): Point | null {
    let t = t0;
    let s = s0;
    let iteration = 0;
    let error = Number.POSITIVE_INFINITY;

    while (error >= tolerance) {
      if (iteration >= iterationLimit) return null;
      const bezier = this.point(t);
      const lineX = segment.a.x + s * (segment.b.x - segment.a.x);
      const lineY = segment.a.y + s * (segment.b.y - segment.a.y);
      const fx = bezier.x - lineX;
      const fy = bezier.y - lineY;
      error = Math.abs(fx) + Math.abs(fy);
      if (error < tolerance) break;

      const d = this.tangent(t);
      const dfxds = -(segment.b.x - segment.a.x);
      const dfyds = -(segment.b.y - segment.a.y);
      const det = d.u * dfyds - dfxds * d.v;
      if (Math.abs(det) < 1e-12) return null;

      const invDet = 1 / det;
      t += invDet * (dfyds * -fx - dfxds * -fy);
      s += invDet * (-d.v * -fx + d.u * -fy);
      iteration += 1;
    }

    if (t < 0 || t > 1 || s < 0 || s > 1) return null;
    return this.point(t);
  }

  /** The closest point on the curve to `p` (`curveClosestPoint`). */
  closestPoint(p: Point, _tolerance = 1e-3): Point {
    const maxSteps = 30;
    let closestStep = 0;
    let minDistance = Number.POSITIVE_INFINITY;
    for (let step = 0; step <= maxSteps; step++) {
      const dist = p.distance(this.point(step / maxSteps));
      if (dist < minDistance) {
        minDistance = dist;
        closestStep = step;
      }
    }

    const t0 = Math.max((closestStep - 1) / maxSteps, 0);
    const t1 = Math.min((closestStep + 1) / maxSteps, 1);
    const t = this.localMinimum(t0, t1, _tolerance, (x) => p.distance(this.point(x)));
    return this.point(t);
  }

  /** Distance from `p` to the closest point on the curve (`curvePointDistance`). */
  distance(p: Point): number {
    return p.distance(this.closestPoint(p));
  }

  private localMinimum(min: number, max: number, e: number, f: (x: number) => number): number {
    let m = min;
    let n = max;
    let k = (m + n) / 2;
    while (n - m > e) {
      k = (n + m) / 2;
      if (f(k - e) < f(k + e)) n = k;
      else m = k;
    }
    return k;
  }
}
