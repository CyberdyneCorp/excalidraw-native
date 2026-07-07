package com.excalidraw.rough

/**
 * Deterministic pseudo-random generator matching rough.js.
 *
 * Park-Miller / "minimal standard" LCG using the multiplier 48271:
 *   state = (state * 48271) mod (2^31 - 1)
 * and [next] returns state / 2^31, giving values in the half-open range [0, 1).
 *
 * The same [seed] always yields the same sequence.
 */
class RoughRandom(seed: Long) {

    private var state: Long = normalize(seed)

    /** Returns the next pseudo-random value in [0, 1). */
    fun next(): Double {
        state = (state * MULTIPLIER) % MODULUS
        return state.toDouble() / TWO_POW_31
    }

    private fun normalize(seed: Long): Long {
        var s = seed % MODULUS
        if (s < 0) s += MODULUS
        if (s == 0L) s = 1L
        return s
    }

    private companion object {
        const val MULTIPLIER = 48271L
        const val MODULUS = 2147483647L // 2^31 - 1
        const val TWO_POW_31 = 2147483648.0 // 2^31
    }
}
