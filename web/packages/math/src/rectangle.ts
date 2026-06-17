import { Point } from "./point.js";
import { LineSegment } from "./segment.js";

/** An axis-aligned rectangle defined by two opposite corners. (parity: Rectangle.swift) */
export class Rectangle {
  constructor(
    public topLeft: Point,
    public bottomRight: Point,
  ) {}

  /** Build from min/max bounds (`rectangleFromNumberSequence`). */
  static fromBounds(minX: number, minY: number, maxX: number, maxY: number): Rectangle {
    return new Rectangle(new Point(minX, minY), new Point(maxX, maxY));
  }

  /** Intersection points of the four edges with a segment (`rectangleIntersectLineSegment`). */
  intersection(segment: LineSegment): Point[] {
    const topRight = new Point(this.bottomRight.x, this.topLeft.y);
    const bottomLeft = new Point(this.topLeft.x, this.bottomRight.y);
    const edges = [
      new LineSegment(this.topLeft, topRight),
      new LineSegment(topRight, this.bottomRight),
      new LineSegment(this.bottomRight, bottomLeft),
      new LineSegment(bottomLeft, this.topLeft),
    ];
    const result: Point[] = [];
    for (const edge of edges) {
      const hit = segment.lineIntersection(edge);
      if (hit !== null) result.push(hit);
    }
    return result;
  }

  /** Whether two rectangles overlap (`rectangleIntersectRectangle`). */
  intersects(other: Rectangle): boolean {
    return (
      this.topLeft.x < other.bottomRight.x &&
      this.bottomRight.x > other.topLeft.x &&
      this.topLeft.y < other.bottomRight.y &&
      this.bottomRight.y > other.topLeft.y
    );
  }
}
