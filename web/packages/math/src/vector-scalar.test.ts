import { describe, expect, it } from "vitest";
import { Angle } from "./angle.js";
import { Point } from "./point.js";
import { InclusiveRange } from "./range.js";
import { average, clamp, isCloseTo, round, roundToStep } from "./utils.js";
import { Vector } from "./vector.js";

const EPS = 4;

describe("Vector", () => {
  it("from points", () => {
    expect(Vector.fromPoint(new Point(4, 6), new Point(1, 2))).toEqual(new Vector(3, 4));
  });

  it("arithmetic and scale", () => {
    expect(new Vector(1, 2).add(new Vector(3, 4))).toEqual(new Vector(4, 6));
    expect(new Vector(5, 5).sub(new Vector(2, 1))).toEqual(new Vector(3, 4));
    expect(new Vector(2, 3).scaled(2)).toEqual(new Vector(4, 6));
  });

  it("dot and cross", () => {
    expect(new Vector(1, 0).dot(new Vector(0, 1))).toBe(0);
    expect(new Vector(2, 3).dot(new Vector(4, 5))).toBe(23);
    expect(new Vector(1, 0).cross(new Vector(0, 1))).toBe(1);
  });

  it("magnitude and normalize", () => {
    expect(new Vector(3, 4).magnitude).toBeCloseTo(5, EPS);
    expect(new Vector(3, 4).magnitudeSquared).toBe(25);
    expect(new Vector(0, 5).normalized()).toEqual(new Vector(0, 1));
    expect(Vector.zero.normalized()).toEqual(Vector.zero);
  });

  it("normal and point", () => {
    expect(new Vector(1, 0).normal()).toEqual(new Vector(0, -1));
    expect(new Vector(2, 3).point(new Point(1, 1))).toEqual(new Point(3, 4));
  });
});

describe("Angle", () => {
  it("normalize radians", () => {
    expect(Angle.normalizeRadians(-Math.PI / 2)).toBeCloseTo(1.5 * Math.PI, EPS);
    expect(Angle.normalizeRadians(2.5 * Math.PI)).toBeCloseTo(0.5 * Math.PI, EPS);
  });

  it("degree/radian conversion", () => {
    expect(Angle.degreesToRadians(180)).toBeCloseTo(Math.PI, EPS);
    expect(Angle.radiansToDegrees(Math.PI)).toBeCloseTo(180, EPS);
  });

  it("cartesian to polar", () => {
    const polar = Angle.cartesianToPolar(new Point(0, 1));
    expect(polar.radius).toBeCloseTo(1, EPS);
    expect(polar.angle).toBeCloseTo(Math.PI / 2, EPS);
  });

  it("is right angle", () => {
    expect(Angle.isRightAngle(Math.PI / 2)).toBe(true);
    expect(Angle.isRightAngle(Math.PI / 3)).toBe(false);
  });

  it("radians between", () => {
    expect(Angle.radiansBetween(Math.PI / 2, 0, Math.PI)).toBe(true);
    expect(Angle.radiansBetween(1.5 * Math.PI, 0, Math.PI)).toBe(false);
    expect(Angle.radiansBetween(0, 1.5 * Math.PI, 0.5 * Math.PI)).toBe(true);
  });

  it("radians difference", () => {
    expect(Angle.radiansDifference(0.1, 6.2)).toBeCloseTo(0.183185, 3);
    expect(Angle.radiansDifference(Math.PI, 0)).toBeCloseTo(Math.PI, EPS);
  });
});

describe("scalar utils", () => {
  it("clamp", () => {
    expect(clamp(5, 0, 10)).toBe(5);
    expect(clamp(-1, 0, 10)).toBe(0);
    expect(clamp(11, 0, 10)).toBe(10);
  });

  it("round", () => {
    expect(round(3.14159, 2)).toBeCloseTo(3.14, 9);
    expect(round(3.7, 0, "floor")).toBeCloseTo(3, 9);
    expect(round(3.1, 0, "ceil")).toBeCloseTo(4, 9);
  });

  it("round to step", () => {
    expect(roundToStep(7, 5)).toBeCloseTo(5, 9);
    expect(roundToStep(8, 5)).toBeCloseTo(10, 9);
  });

  it("average and isCloseTo", () => {
    expect(average(2, 4)).toBe(3);
    expect(isCloseTo(1.0, 1.0 + 1e-6)).toBe(true);
    expect(isCloseTo(1.0, 1.1)).toBe(false);
  });
});

describe("InclusiveRange", () => {
  it("overlaps", () => {
    expect(new InclusiveRange(1, 3).overlaps(new InclusiveRange(2, 4))).toBe(true);
    expect(new InclusiveRange(1, 3).overlaps(new InclusiveRange(4, 5))).toBe(false);
  });

  it("intersection", () => {
    expect(new InclusiveRange(1, 3).intersection(new InclusiveRange(2, 4))).toEqual(
      new InclusiveRange(2, 3),
    );
    expect(new InclusiveRange(1, 2).intersection(new InclusiveRange(3, 4))).toBeNull();
  });

  it("includes", () => {
    expect(new InclusiveRange(0, 10).includes(5)).toBe(true);
    expect(new InclusiveRange(0, 10).includes(11)).toBe(false);
  });
});
