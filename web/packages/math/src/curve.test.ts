import { describe, expect, it } from "vitest";
import { Curve } from "./curve.js";
import { Point } from "./point.js";
import { LineSegment } from "./segment.js";

/** Independent reference: arc length by fine-grained polyline sampling. */
function sampledLength(c: Curve, steps = 20000): number {
  let total = 0;
  let prev = c.point(0);
  for (let i = 1; i <= steps; i++) {
    const cur = c.point(i / steps);
    total += prev.distance(cur);
    prev = cur;
  }
  return total;
}

describe("Curve math", () => {
  it("straight curve length is exact", () => {
    const c = new Curve(new Point(0, 0), new Point(1, 0), new Point(2, 0), new Point(3, 0));
    expect(c.length).toBeCloseTo(3, 9);
  });

  it("curved length matches sampled reference", () => {
    const c = new Curve(new Point(0, 0), new Point(0, 10), new Point(10, 10), new Point(10, 0));
    expect(c.length).toBeCloseTo(sampledLength(c), 4);
  });

  it("partial length endpoints and monotonic", () => {
    const c = new Curve(new Point(0, 0), new Point(0, 10), new Point(10, 10), new Point(10, 0));
    expect(c.lengthAt(0)).toBeCloseTo(0, 12);
    expect(c.lengthAt(1)).toBeCloseTo(c.length, 9);
    const quarter = c.lengthAt(0.25);
    const half = c.lengthAt(0.5);
    expect(half).toBeGreaterThan(quarter);
    expect(half).toBeLessThan(c.length);
  });

  it("point at length endpoints and midpoint", () => {
    const c = new Curve(new Point(0, 0), new Point(0, 10), new Point(10, 10), new Point(10, 0));
    expect(c.pointAtLength(0)).toEqual(c.point(0));
    expect(c.pointAtLength(1)).toEqual(c.point(1));
    expect(c.pointAtLength(0.5).x).toBeCloseTo(5, 3);
  });

  it("intersection with a crossing segment", () => {
    const c = new Curve(new Point(0, 0), new Point(0, 10), new Point(10, 10), new Point(10, 0));
    const hits = c.intersections(new LineSegment(new Point(-5, 5), new Point(15, 5)));
    expect(hits.length).toBe(1);
    expect(hits[0]!.y).toBeCloseTo(5, 2);
    expect(hits[0]!.x).toBeGreaterThanOrEqual(0);
    expect(hits[0]!.x).toBeLessThanOrEqual(10);
  });

  it("no intersection when the segment is far away", () => {
    const c = new Curve(new Point(0, 0), new Point(0, 10), new Point(10, 10), new Point(10, 0));
    expect(c.intersections(new LineSegment(new Point(-5, 100), new Point(15, 100)))).toHaveLength(
      0,
    );
  });

  it("closest point on a straight curve", () => {
    const c = new Curve(new Point(0, 0), new Point(1, 0), new Point(2, 0), new Point(3, 0));
    const closest = c.closestPoint(new Point(1.5, 5));
    expect(closest.x).toBeCloseTo(1.5, 2);
    expect(closest.y).toBeCloseTo(0, 2);
  });

  it("distance to curve", () => {
    const c = new Curve(new Point(0, 0), new Point(1, 0), new Point(2, 0), new Point(3, 0));
    expect(c.distance(new Point(1.5, 4))).toBeCloseTo(4, 2);
  });
});
