import { describe, expect, it } from "vitest";
import { Ellipse } from "./ellipse.js";
import { Line } from "./line.js";
import { Point } from "./point.js";
import { InclusiveRange } from "./range.js";
import { LineSegment } from "./segment.js";
import { Triangle } from "./triangle.js";
import { roundToStep } from "./utils.js";

describe("math edge cases", () => {
  it("parallel segments return null", () => {
    expect(
      new LineSegment(new Point(0, 0), new Point(10, 0)).intersection(
        new LineSegment(new Point(0, 5), new Point(10, 5)),
      ),
    ).toBeNull();
  });

  it("collinear (shared start) segments return null", () => {
    expect(
      new LineSegment(new Point(0, 0), new Point(10, 0)).intersection(
        new LineSegment(new Point(0, 0), new Point(0, 10)),
      ),
    ).toBeNull();
  });

  it("line intersection outside segment bounds", () => {
    expect(
      new LineSegment(new Point(0, 0), new Point(1, 1)).lineIntersection(
        new LineSegment(new Point(10, 0), new Point(9, 1)),
      ),
    ).toBeNull();
  });

  it("range overlap when first starts later", () => {
    expect(new InclusiveRange(4, 6).overlaps(new InclusiveRange(1, 5))).toBe(true);
    expect(new InclusiveRange(6, 8).overlaps(new InclusiveRange(1, 4))).toBe(false);
  });

  it("ellipse tangent line returns a single point", () => {
    const circle = new Ellipse(Point.zero, 10, 10);
    const points = circle.intersectionWithLine(new Line(new Point(-100, 10), new Point(100, 10)));
    expect(points.length).toBe(1);
    expect(points[0]!.x).toBeCloseTo(0, 3);
    expect(points[0]!.y).toBeCloseTo(10, 3);
  });

  it("round to step modes", () => {
    expect(roundToStep(7, 5, "floor")).toBeCloseTo(5, 9);
    expect(roundToStep(6, 5, "ceil")).toBeCloseTo(10, 9);
  });

  it("triangle point on opposite sides", () => {
    const t = new Triangle(new Point(0, 0), new Point(10, 0), new Point(5, 10));
    expect(t.includes(new Point(-5, 5))).toBe(false);
    expect(t.includes(new Point(20, 5))).toBe(false);
  });
});
