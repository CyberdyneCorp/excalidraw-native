import Foundation

/// Deterministic pseudo-random generator seeded per element.
///
/// rough.js produces its hand-drawn look by perturbing vertices with a seeded
/// RNG (`element.seed`), so the same element always renders identically.
/// Reproducing that determinism — and using rough.js's exact generator — is what
/// keeps our output reproducible and aligned with excalidraw.com.
///
/// Ports rough.js `Random` (core.ts):
/// `next() = ((2**31 - 1) & (seed = Math.imul(48271, seed))) / 2**31`.
/// `Math.imul` is a 32-bit signed multiply, matched here by `Int32` overflow
/// multiplication. A zero seed yields a constant sequence (Excalidraw seeds are
/// always positive 31-bit integers).
///
/// See `packages/element/src/shape.ts` (`generateRoughOptions`, `element.seed`).
public struct SeededRandom: Sendable {
    private var seed: Int32

    public init(seed: Int) {
        self.seed = Int32(truncatingIfNeeded: seed)
    }

    /// Next value in [0, 1), advancing the generator (rough.js `Random.next`).
    public mutating func next() -> Double {
        seed = 48271 &* seed
        let masked = seed & 0x7FFF_FFFF
        return Double(masked) / 2_147_483_648 // 2**31
    }
}

public enum RoughKit {
    /// Default roughness (upstream `ROUGHNESS.artist`).
    public static let defaultRoughness = 1.0
}
