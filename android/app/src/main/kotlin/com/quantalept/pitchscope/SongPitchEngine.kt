package com.quantalept.pitchscope

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import kotlin.math.abs
import kotlin.math.log2
import kotlin.math.pow
import kotlin.concurrent.thread

class SongPitchEngine(private val context: Context) {

    private var audioRecord: AudioRecord? = null
    private var isRunning = false
    private var workerThread: Thread? = null

    private val sampleRate = 22050
    private val bufferSize = 2048

    /**
     * Start REAL microphone pitch detection (no external libs)
     */
    fun start(onPitchDetected: (Double) -> Unit) {
        stop()

        val minBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBuffer
        )

        val buffer = ShortArray(bufferSize)

        isRunning = true

        audioRecord?.startRecording()

        workerThread = thread(start = true, name = "PitchThread") {

            while (isRunning) {
                val read = audioRecord?.read(buffer, 0, bufferSize) ?: 0

                if (read > 0) {
                    val pitch = detectPitch(buffer, read, sampleRate)

                    if (pitch > 50 && pitch < 2000) {
                        onPitchDetected(pitch)
                    }
                }
            }
        }
    }

    /**
     * Simple autocorrelation pitch detection (no libraries)
     */
    private fun detectPitch(data: ShortArray, size: Int, sampleRate: Int): Double {

        var bestOffset = -1
        var bestCorrelation = 0.0

        for (offset in 20 until size / 2) {

            var correlation = 0.0

            for (i in 0 until size - offset) {
                correlation += (data[i] * data[i + offset]).toDouble()
            }

            if (correlation > bestCorrelation) {
                bestCorrelation = correlation
                bestOffset = offset
            }
        }

        if (bestOffset <= 0) return -1.0

        return sampleRate.toDouble() / bestOffset
    }

    /**
     * Stop engine
     */
    fun stop() {
        isRunning = false

        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            Log.e("SongPitchEngine", "Stop error", e)
        }

        audioRecord = null
        workerThread?.interrupt()
        workerThread = null
    }
}