import { PRECISION, type Point } from "./point.js";

const TWO_PI = 2 * Math.PI;

/** Wrap an angle into `[0, 2π)` (`normalizeRadians`). */
export function normalizeRadians(angle: number): number {
  const remainder = angle % TWO_PI;
  return angle < 0 ? remainder + TWO_PI : remainder;
}

export function degreesToRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

export function radiansToDegrees(radians: number): number {
  return (radians * 180) / Math.PI;
}

/** Polar `(radius, angle)` of a cartesian point about the origin (`cartesian2Polar`). */
export function cartesianToPolar(point: Point): { radius: number; angle: number } {
  return {
    radius: Math.hypot(point.x, point.y),
    angle: normalizeRadians(Math.atan2(point.y, point.x)),
  };
}

/** Whether `radians` is (close to) a right angle (`isRightAngleRads`). */
export function isRightAngle(radians: number): boolean {
  return Math.abs(Math.sin(2 * radians)) < PRECISION;
}

/** Whether `angle` lies within `[min, max]`, accounting for wrap-around. */
export function radiansBetween(angle: number, min: number, max: number): boolean {
  const a = normalizeRadians(angle);
  const lo = normalizeRadians(min);
  const hi = normalizeRadians(max);
  if (lo < hi) return a >= lo && a <= hi;
  return a >= lo || a <= hi; // range wraps past 0
}

/** Smallest absolute difference between two angles (`radiansDifference`). */
export function radiansDifference(a: number, b: number): number {
  let diff = normalizeRadians(a) - normalizeRadians(b);
  if (diff < -Math.PI) {
    diff += TWO_PI;
  } else if (diff > Math.PI) {
    diff -= TWO_PI;
  }
  return Math.abs(diff);
}

/** Namespace object mirroring the Swift `Angle` enum. */
export const Angle = {
  normalizeRadians,
  degreesToRadians,
  radiansToDegrees,
  cartesianToPolar,
  isRightAngle,
  radiansBetween,
  radiansDifference,
} as const;
