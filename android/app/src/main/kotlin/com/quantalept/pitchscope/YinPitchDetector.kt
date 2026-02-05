package com.quantalept.pitchscope

class YinPitchDetector(
    private val sampleRate: Int,
    bufferSize: Int
) {

    private val yinBuffer = FloatArray(bufferSize / 2)

    fun getPitch(buffer: ShortArray, size: Int): Double {
        if (size < yinBuffer.size * 2) return -1.0

        difference(buffer, size)
        cumulativeMeanNormalizedDifference()
        val tau = absoluteThreshold()

        return if (tau != -1) {
            val betterTau = parabolicInterpolation(tau)
            sampleRate.toDouble() / betterTau
        } else {
            -1.0
        }
    }

    private fun difference(buffer: ShortArray, size: Int) {
        yinBuffer.fill(0f)

        for (tau in 1 until yinBuffer.size) {
            var sum = 0f
            var i = 0

            while (i + tau < size) {
                val delta = buffer[i] - buffer[i + tau]
                sum += delta * delta
                i++
            }

            yinBuffer[tau] = sum
        }
    }

    private fun cumulativeMeanNormalizedDifference() {
        yinBuffer[0] = 1f
        var runningSum = 0f

        for (tau in 1 until yinBuffer.size) {
            runningSum += yinBuffer[tau]
            yinBuffer[tau] = if (runningSum == 0f) 1f else yinBuffer[tau] * tau / runningSum
        }
    }

    private fun absoluteThreshold(): Int {
        val threshold = 0.15f

        for (tau in 2 until yinBuffer.size - 1) {
            if (
                yinBuffer[tau] < threshold &&
                yinBuffer[tau] < yinBuffer[tau - 1]
            ) {
                return tau
            }
        }
        return -1
    }

    private fun parabolicInterpolation(tau: Int): Double {
        val x0 = if (tau > 0) tau - 1 else tau
        val x2 = if (tau + 1 < yinBuffer.size) tau + 1 else tau

        if (x0 == tau || x2 == tau) return tau.toDouble()

        val s0 = yinBuffer[x0]
        val s1 = yinBuffer[tau]
        val s2 = yinBuffer[x2]

        return tau.toDouble() +
                (s2 - s0) /
                (2.0 * (2.0 * s1 - s2 - s0))
    }
}