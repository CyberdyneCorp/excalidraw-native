import { Point } from "./point.js";

/** A 2D vector. (parity: Sources/ExcalidrawMath/Vector.swift) */
export class Vector {
  constructor(
    public u: number,
    public v: number,
  ) {}

  static readonly zero = new Vector(0, 0);

  /** Vector from `origin` to `point` (`vectorFromPoint`). */
  static fromPoint(point: Point, origin: Point = Point.zero): Vector {
    return new Vector(point.x - origin.x, point.y - origin.y);
  }

  add(other: Vector): Vector {
    return new Vector(this.u + other.u, this.v + other.v);
  }

  sub(other: Vector): Vector {
    return new Vector(this.u - other.u, this.v - other.v);
  }

  scaled(scalar: number): Vector {
    return new Vector(this.u * scalar, this.v * scalar);
  }

  /** 2D cross product (scalar z-component) (`vectorCross`). */
  cross(other: Vector): number {
    return this.u * other.v - other.u * this.v;
  }

  /** Dot product (`vectorDot`). */
  dot(other: Vector): number {
    return this.u * other.u + this.v * other.v;
  }

  get magnitudeSquared(): number {
    return this.u * this.u + this.v * this.v;
  }

  get magnitude(): number {
    return Math.sqrt(this.magnitudeSquared);
  }

  /** Unit vector, or zero when magnitude is zero (`vectorNormalize`). */
  normalized(): Vector {
    const m = this.magnitude;
    return m === 0 ? Vector.zero : new Vector(this.u / m, this.v / m);
  }

  /** Right-hand normal (`vectorNormal`). */
  normal(): Vector {
    return new Vector(this.v, -this.u);
  }

  /** The point this vector points at from `offset` (`pointFromVector`). */
  point(offset: Point = Point.zero): Point {
    return new Point(offset.x + this.u, offset.y + this.v);
  }
}
