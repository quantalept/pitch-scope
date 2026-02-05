package com.example.pitchscope

import android.media.*
import android.os.Process
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlin.math.*

class RealTimeAudioStream(
    private val channel: MethodChannel
) {

    private val sampleRate = 44100

    private val bufferSize = AudioRecord.getMinBufferSize(
        sampleRate,
        AudioFormat.CHANNEL_IN_MONO,
        AudioFormat.ENCODING_PCM_16BIT
    )

    private val audioRecord = AudioRecord(
        MediaRecorder.AudioSource.MIC,
        sampleRate,
        AudioFormat.CHANNEL_IN_MONO,
        AudioFormat.ENCODING_PCM_16BIT,
        bufferSize
    )

    private var job: Job? = null

    fun start() {
        if (job != null) return

        job = CoroutineScope(Dispatchers.Default).launch {
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)

            val buffer = ShortArray(bufferSize)
            audioRecord.startRecording()

            while (isActive) {
                val read = audioRecord.read(buffer, 0, buffer.size)

                if (read > 0) {
                    val hz = detectPitch(buffer, read)

                    withContext(Dispatchers.Main) {
                        channel.invokeMethod("pitch", hz)
                    }
                }

                delay(40) // 🔹 Faster updates
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
        audioRecord.stop()
        audioRecord.release() // 🔹 Release resources
    }

    // ---------- Pitch detection (autocorrelation) ----------
    private fun detectPitch(buffer: ShortArray, size: Int): Double {
        val minLag = sampleRate / 1000  // ~44Hz
        val maxLag = sampleRate / 50    // ~882Hz

        var bestLag = -1
        var bestCorr = 0.0

        for (lag in minLag until maxLag) {
            var sum = 0.0
            for (i in 0 until size - lag) {
                sum += buffer[i] * buffer[i + lag]
            }
            if (sum > bestCorr) {
                bestCorr = sum
                bestLag = lag
            }
        }

        return if (bestLag > 0) sampleRate.toDouble() / bestLag else 0.0
    }
}