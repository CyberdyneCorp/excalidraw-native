import { describe, expect, it } from "vitest";
import { Curve } from "./curve.js";
import { Ellipse } from "./ellipse.js";
import { Line } from "./line.js";
import { Point } from "./point.js";
import { Polygon } from "./polygon.js";
import { Rectangle } from "./rectangle.js";
import { LineSegment } from "./segment.js";
import { Triangle } from "./triangle.js";

const EPS = 4;

describe("Line and segment", () => {
  it("line intersection", () => {
    const p = new Line(new Point(0, 0), new Point(2, 2)).intersection(
      new Line(new Point(0, 2), new Point(2, 0)),
    );
    expect(p?.x ?? Number.NaN).toBeCloseTo(1, EPS);
    expect(p?.y ?? Number.NaN).toBeCloseTo(1, EPS);
  });

  it("parallel lines do not intersect", () => {
    expect(
      new Line(new Point(0, 0), new Point(1, 0)).intersection(
        new Line(new Point(0, 1), new Point(1, 1)),
      ),
    ).toBeNull();
  });

  it("distance to segment", () => {
    const segment = new LineSegment(new Point(0, 0), new Point(10, 0));
    expect(segment.distanceToPoint(new Point(5, 3))).toBeCloseTo(3, EPS);
    expect(segment.distanceToPoint(new Point(-5, 0))).toBeCloseTo(5, EPS);
  });

  it("segment contains", () => {
    const segment = new LineSegment(new Point(0, 0), new Point(10, 0));
    expect(segment.contains(new Point(5, 0))).toBe(true);
    expect(segment.contains(new Point(5, 1))).toBe(false);
  });

  it("segments intersect", () => {
    const p = new LineSegment(new Point(0, 0), new Point(10, 10)).intersection(
      new LineSegment(new Point(0, 10), new Point(10, 0)),
    );
    expect(p?.x ?? Number.NaN).toBeCloseTo(5, EPS);
    expect(p?.y ?? Number.NaN).toBeCloseTo(5, EPS);
  });

  it("non-crossing segments return null", () => {
    expect(
      new LineSegment(new Point(0, 0), new Point(1, 0)).intersection(
        new LineSegment(new Point(0, 5), new Point(1, 5)),
      ),
    ).toBeNull();
  });

  it("distance between segments", () => {
    const a = new LineSegment(new Point(0, 0), new Point(10, 0));
    expect(a.distanceToSegment(new LineSegment(new Point(0, 4), new Point(10, 4)))).toBeCloseTo(
      4,
      EPS,
    );
    expect(a.distanceToSegment(new LineSegment(new Point(5, -5), new Point(5, 5)))).toBeCloseTo(
      0,
      EPS,
    );
  });
});

describe("Triangle and rectangle", () => {
  it("triangle includes", () => {
    const t = new Triangle(new Point(0, 0), new Point(10, 0), new Point(0, 10));
    expect(t.includes(new Point(2, 2))).toBe(true);
    expect(t.includes(new Point(8, 8))).toBe(false);
  });

  it("rectangle intersects a segment", () => {
    const rect = Rectangle.fromBounds(0, 0, 10, 10);
    expect(rect.intersection(new LineSegment(new Point(-5, 5), new Point(15, 5))).length).toBe(2);
  });

  it("rectangle intersects a rectangle", () => {
    const a = Rectangle.fromBounds(0, 0, 10, 10);
    expect(a.intersects(Rectangle.fromBounds(5, 5, 15, 15))).toBe(true);
    expect(a.intersects(Rectangle.fromBounds(20, 20, 30, 30))).toBe(false);
  });
});

describe("Polygon", () => {
  const square = new Polygon([
    new Point(0, 0),
    new Point(10, 0),
    new Point(10, 10),
    new Point(0, 10),
  ]);

  it("includes (even-odd)", () => {
    expect(square.includes(new Point(5, 5))).toBe(true);
    expect(square.includes(new Point(15, 5))).toBe(false);
  });

  it("includes (non-zero)", () => {
    expect(square.includesNonZero(new Point(5, 5))).toBe(true);
    expect(square.includesNonZero(new Point(-1, 5))).toBe(false);
  });

  it("point on edge", () => {
    expect(square.contains(new Point(5, 0))).toBe(true);
    expect(square.contains(new Point(5, 5))).toBe(false);
  });

  it("auto-closes", () => {
    expect(square.points[0]).toEqual(square.points[square.points.length - 1]);
  });
});

describe("Ellipse and curve", () => {
  const circle = new Ellipse(Point.zero, 10, 10);

  it("includes", () => {
    expect(circle.includes(new Point(5, 0))).toBe(true);
    expect(circle.includes(new Point(11, 0))).toBe(false);
  });

  it("distance from point", () => {
    expect(circle.distance(new Point(20, 0))).toBeCloseTo(10, 3);
    expect(circle.touches(new Point(10, 0), 1e-2)).toBe(true);
  });

  it("segment intersection", () => {
    const points = circle.intersectionWithSegment(
      new LineSegment(new Point(-100, 0), new Point(100, 0)),
    );
    expect(points.length).toBe(2);
    const xs = points.map((p) => p.x).sort((a, b) => a - b);
    expect(xs[0] ?? Number.NaN).toBeCloseTo(-10, EPS);
    expect(xs[xs.length - 1] ?? Number.NaN).toBeCloseTo(10, EPS);
  });

  it("line intersection", () => {
    expect(
      circle.intersectionWithLine(new Line(new Point(-100, 0), new Point(100, 0))).length,
    ).toBe(2);
  });

  it("curve evaluation", () => {
    const curve = new Curve(new Point(0, 0), new Point(0, 10), new Point(10, 10), new Point(10, 0));
    expect(curve.point(0)).toEqual(new Point(0, 0));
    expect(curve.point(1)).toEqual(new Point(10, 0));
    const mid = curve.point(0.5);
    expect(mid.x).toBeCloseTo(5, EPS);
    expect(mid.y).toBeCloseTo(7.5, EPS);
  });

  it("curve tangent", () => {
    const curve = new Curve(new Point(0, 0), new Point(1, 0), new Point(2, 0), new Point(3, 0));
    expect(curve.tangent(0.5).v).toBeCloseTo(0, EPS);
    expect(curve.tangent(0.5).u).toBeGreaterThan(0);
  });
});
