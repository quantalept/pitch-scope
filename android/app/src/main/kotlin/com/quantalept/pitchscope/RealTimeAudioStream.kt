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
    private var lastPitch = 0.0

    fun start() {
        if (job != null) return

        job = CoroutineScope(Dispatchers.Default).launch {
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)

            val buffer = ShortArray(bufferSize)
            audioRecord.startRecording()

            while (isActive) {
                val read = audioRecord.read(buffer, 0, buffer.size)
                if (read <= 0) continue

                // 🔇 1. RMS volume gate (ignore silence / noise)
                val rms = calculateRMS(buffer, read)
                if (rms < 1200) {
                    lastPitch = 0.0
                    withContext(Dispatchers.Main) {
                        channel.invokeMethod("pitch", -1.0)
                    }
                    delay(40)
                    continue
                }

                // 🎯 2. Pitch detection
                val hz = detectPitch(buffer, read)

                // ❌ Invalid pitch guard
                if (hz < 80 || hz > 1200) {
                    withContext(Dispatchers.Main) {
                        channel.invokeMethod("pitch", -1.0)
                    }
                    delay(40)
                    continue
                }

                // 🧠 3. Temporal smoothing (reduces jitter)
                val smoothedHz =
                    if (lastPitch == 0.0) hz
                    else lastPitch * 0.75 + hz * 0.25

                lastPitch = smoothedHz

                withContext(Dispatchers.Main) {
                    channel.invokeMethod("pitch", smoothedHz)
                }

                delay(40) // readable speed
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
        if (audioRecord.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
            audioRecord.stop()
        }
    }

    // ---------- RMS (volume detection) ----------
    private fun calculateRMS(buffer: ShortArray, size: Int): Double {
        var sum = 0.0
        for (i in 0 until size) {
            val v = buffer[i].toDouble()
            sum += v * v
        }
        return sqrt(sum / size)
    }

    // ---------- Pitch detection (autocorrelation) ----------
    private fun detectPitch(buffer: ShortArray, size: Int): Double {
        val minLag = sampleRate / 1000   // ~44 Hz
        val maxLag = sampleRate / 80     // ~550 Hz (human vocal focus)

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
