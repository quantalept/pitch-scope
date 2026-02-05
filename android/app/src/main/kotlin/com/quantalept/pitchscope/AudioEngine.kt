package com.quantalept.pitchscope

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper

class AudioEngine(
    private val onFrame: (Double, List<Double>) -> Unit
) {

    private var isRecording = false
    private var audioRecord: AudioRecord? = null

    private val sampleRate = 44100
    private val bufferSize = 2048   // ✅ LOW LATENCY

    private val buffer = ShortArray(bufferSize)
    private val yinDetector = YinPitchDetector(sampleRate, bufferSize)

    private val mainHandler = Handler(Looper.getMainLooper())

    fun start() {
        if (isRecording) return

        // ✅ Ensure buffer size is valid on all devices
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
            val readBuffer = ShortArray(buffer.size)  // local buffer
            while (isRecording) {
                val read = audioRecord?.read(readBuffer, 0, readBuffer.size) ?: 0
                if (read <= 0) continue

                // ✅ Pitch detection
                val pitchHz = yinDetector.getPitch(readBuffer, read)

                // ✅ Normalized waveform for UI (first 256 samples)
                val samples = readBuffer
                    .take(256)
                    .map { it.toDouble() / 32768.0 }

                // ✅ Post to main thread safely
                mainHandler.post {
                    onFrame(if (pitchHz > 0) pitchHz else 0.0, samples)
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
}