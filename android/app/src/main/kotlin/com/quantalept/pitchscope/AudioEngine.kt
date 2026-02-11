package com.quantalept.pitchscope

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlin.math.*

class AudioEngine(
    private val onPitch: (Double) -> Unit
) {

    private var isRecording = false
    private var audioRecord: AudioRecord? = null

    private val sampleRate = 44100
    private val bufferSize = 2048

    fun start() {
        if (isRecording) return

        val minBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        val finalBufferSize = maxOf(bufferSize * 2, minBuffer)

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            finalBufferSize
        )

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            throw RuntimeException("AudioRecord initialization failed")
        }

        audioRecord?.startRecording()
        isRecording = true

        Thread {
            val buffer = ShortArray(bufferSize)

            while (isRecording) {

                val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                if (read <= 0) continue

                // -------------------------
                // 1️⃣ RMS VOLUME GATING
                // -------------------------
                var sum = 0.0
                for (i in 0 until read) {
                    sum += buffer[i] * buffer[i]
                }

                val rms = sqrt(sum / read)
                val level = rms / 32768.0

                // Ignore very quiet sounds (hiss, room noise)
                if (level < 0.05) {
                    onPitch(0.0)
                    continue
                }

                // -------------------------
                // 2️⃣ PITCH DETECTION
                // -------------------------
                val pitch = estimatePitch(buffer, read)

                // Reject unrealistic human frequencies
                if (pitch !in 60.0..1200.0) {
                    continue
                }

                onPitch(pitch)
            }

        }.start()
    }

    fun stop() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }

    // ---------------------------------
    // Auto-correlation Pitch Detection
    // ---------------------------------
    private fun estimatePitch(
        buffer: ShortArray,
        size: Int
    ): Double {

        var bestLag = 0
        var maxCorr = 0.0

        for (lag in 40..1000) {

            var corr = 0.0

            for (i in 0 until size - lag) {
                corr += buffer[i] * buffer[i + lag]
            }

            if (corr > maxCorr) {
                maxCorr = corr
                bestLag = lag
            }
        }

        // Reject weak correlation (random noise)
        if (maxCorr < 1e9) return 0.0

        return if (bestLag > 0)
            sampleRate.toDouble() / bestLag
        else
            0.0
    }
}
