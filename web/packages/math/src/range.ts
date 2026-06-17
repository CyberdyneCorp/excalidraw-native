/** An inclusive numeric range `[start, end]`. (parity: Range.swift) */
export class InclusiveRange {
  constructor(
    public start: number,
    public end: number,
  ) {}

  /** Whether this range overlaps `other` (`rangesOverlap`). */
  overlaps(other: InclusiveRange): boolean {
    if (this.start <= other.start) return this.end >= other.start;
    return other.end >= this.start;
  }

  /** The overlapping range, or `null` when disjoint (`rangeIntersection`). */
  intersection(other: InclusiveRange): InclusiveRange | null {
    const lo = Math.max(this.start, other.start);
    const hi = Math.min(this.end, other.end);
    return lo <= hi ? new InclusiveRange(lo, hi) : null;
  }

  /** Whether `value` lies inside the range (`rangeIncludesValue`). */
  includes(value: number): boolean {
    return value >= this.start && value <= this.end;
  }
}
