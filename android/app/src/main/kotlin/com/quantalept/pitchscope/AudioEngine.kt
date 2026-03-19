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

    private val sampleRate = 22050   // reduced for stability
    private val bufferSize = 1024    // smaller buffer = less CPU

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

                val pitch = detectPitch(buffer, read)

                if (pitch in 60.0..1200.0) {
                    onPitch(pitch)
                } else {
                    onPitch(0.0)
                }
            }

        }.start()
    }

    fun stop() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }

    private fun detectPitch(buffer: ShortArray, size: Int): Double {

        // RMS noise gate (light)
        var sum = 0.0
        for (i in 0 until size) {
            sum += buffer[i] * buffer[i]
        }
        val rms = sqrt(sum / size)
        val level = rms / 32768.0

        if (level < 0.01) return 0.0

        val minFreq = 80.0
        val maxFreq = 1000.0

        val minLag = (sampleRate / maxFreq).toInt()
        val maxLag = (sampleRate / minFreq).toInt()

        var bestLag = 0
        var maxCorr = 0.0

        for (lag in minLag..maxLag) {

            var corr = 0.0

            // step 2 reduces CPU usage
            for (i in 0 until size - lag step 2) {
                corr += buffer[i] * buffer[i + lag]
            }

            if (corr > maxCorr) {
                maxCorr = corr
                bestLag = lag
            }
        }

        if (bestLag == 0) return 0.0

        return sampleRate.toDouble() / bestLag
    }
}