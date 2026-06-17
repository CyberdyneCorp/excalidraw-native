import { describe, expect, it } from "vitest";
import { Point } from "./point.js";
import { Vector } from "./vector.js";

const EPS = 4; // ~1e-4 decimal places

describe("Point", () => {
  it("distance", () => {
    expect(new Point(0, 0).distance(new Point(3, 4))).toBeCloseTo(5, EPS);
  });

  it("arithmetic", () => {
    expect(new Point(1, 2).add(new Point(3, 4))).toEqual(new Point(4, 6));
    expect(new Point(5, 5).sub(new Point(2, 1))).toEqual(new Point(3, 4));
  });

  it("magnitude", () => {
    expect(new Point(3, 4).magnitude).toBeCloseTo(5, EPS);
  });

  it("encodes as a JSON array", () => {
    expect(JSON.stringify(new Point(1.5, -2).toArray())).toBe("[1.5,-2]");
  });

  it("decodes from a JSON array", () => {
    expect(Point.fromArray(JSON.parse("[3,4]"))).toEqual(new Point(3, 4));
  });
});

describe("Point ops", () => {
  it("rotate 90° around origin", () => {
    const r = new Point(1, 0).rotated(Point.zero, Math.PI / 2);
    expect(r.x).toBeCloseTo(0, EPS);
    expect(r.y).toBeCloseTo(1, EPS);
  });

  it("rotate by zero is identity", () => {
    expect(new Point(3, 7).rotated(new Point(1, 1), 0)).toEqual(new Point(3, 7));
  });

  it("rotate around a center", () => {
    const r = new Point(2, 1).rotated(new Point(1, 1), Math.PI);
    expect(r.x).toBeCloseTo(0, EPS);
    expect(r.y).toBeCloseTo(1, EPS);
  });

  it("translate", () => {
    expect(new Point(1, 2).translated(new Vector(3, -1))).toEqual(new Point(4, 1));
  });

  it("midpoint", () => {
    expect(new Point(0, 0).midpoint(new Point(4, 6))).toEqual(new Point(2, 3));
  });

  it("distance squared", () => {
    expect(new Point(0, 0).distanceSquared(new Point(3, 4))).toBe(25);
  });

  it("scale from origin", () => {
    expect(new Point(2, 2).scaledFrom(Point.zero, 2)).toEqual(new Point(4, 4));
    expect(new Point(3, 3).scaledFrom(new Point(1, 1), 2)).toEqual(new Point(5, 5));
  });

  it("is within bounds", () => {
    expect(new Point(2, 2).isWithin(new Point(0, 0), new Point(4, 4))).toBe(true);
    expect(new Point(5, 2).isWithin(new Point(0, 0), new Point(4, 4))).toBe(false);
  });

  it("approximate equality", () => {
    expect(new Point(1, 1).isApproximatelyEqual(new Point(1 + 10e-5 / 2, 1))).toBe(true);
    expect(new Point(1, 1).isApproximatelyEqual(new Point(1.01, 1))).toBe(false);
  });
});
