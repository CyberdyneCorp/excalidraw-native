import XCTest
@testable import RoughKit

final class SeededRandomTests: XCTestCase {
    func testDeterministicForSameSeed() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        for _ in 0 ..< 100 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiverge() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        let seqA = (0 ..< 10).map { _ in a.next() }
        let seqB = (0 ..< 10).map { _ in b.next() }
        XCTAssertNotEqual(seqA, seqB)
    }

    func testValuesInUnitRange() {
        var rng = SeededRandom(seed: 7)
        for _ in 0 ..< 1000 {
            let v = rng.next()
            XCTAssertGreaterThanOrEqual(v, 0)
            XCTAssertLessThan(v, 1)
        }
    }

    func testMatchesRoughJSReferenceSequence() {
        // Reference values computed from rough.js Random:
        // next() = ((2**31 - 1) & (seed = imul(48271, seed))) / 2**31
        // for seed = 1: imul(48271,1)=48271 -> 48271/2**31, then imul(48271,48271)=2330118241...
        var rng = SeededRandom(seed: 1)
        XCTAssertEqual(rng.next(), 48271.0 / 2_147_483_648.0, accuracy: 1e-12)
        // Second: 48271 * 48271 = 2_330_089_441; & 0x7FFFFFFF = 2_330_089_441 - 2_147_483_648
        let second = Double(2_330_089_441 & 0x7FFF_FFFF) / 2_147_483_648.0
        XCTAssertEqual(rng.next(), second, accuracy: 1e-12)
    }

    func testZeroSeedIsConstant() {
        // rough.js uses Math.random() for a zero seed; our deterministic port
        // yields a constant sequence instead (real elements never use seed 0).
        var rng = SeededRandom(seed: 0)
        XCTAssertEqual(rng.next(), 0)
        XCTAssertEqual(rng.next(), 0)
    }
}
