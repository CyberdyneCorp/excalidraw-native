import { PRECISION } from "./point.js";

export type Rounding = "round" | "floor" | "ceil";

function applyRounding(value: number, mode: Rounding): number {
  switch (mode) {
    case "round":
      return Math.round(value);
    case "floor":
      return Math.floor(value);
    case "ceil":
      return Math.ceil(value);
  }
}

/** Clamp `value` into `[min, max]`. */
export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

/**
 * Round `value` to `precision` decimal places. Mirrors the Swift `round`, which
 * nudges by one ULP of 1.0 (`Number.EPSILON`) before scaling.
 */
export function round(value: number, precision: number, mode: Rounding = "round"): number {
  const multiplier = 10 ** precision;
  const scaled = (value + Number.EPSILON) * multiplier;
  return applyRounding(scaled, mode) / multiplier;
}

/** Round `value` to the nearest multiple of `step` (`roundToStep`). */
export function roundToStep(value: number, step: number, mode: Rounding = "round"): number {
  const factor = 1 / step;
  return applyRounding(value * factor, mode) / factor;
}

export function average(a: number, b: number): number {
  return (a + b) / 2;
}

/** Whether `a` and `b` are within `precision` of each other (`isCloseTo`). */
export function isCloseTo(a: number, b: number, precision: number = PRECISION): boolean {
  return Math.abs(a - b) < precision;
}
