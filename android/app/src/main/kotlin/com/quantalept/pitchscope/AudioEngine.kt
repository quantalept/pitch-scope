package com.quantalept.pitchscope

import android.media.*
import java.io.FileInputStream
import kotlin.math.*

class AudioEngine(
    private val onPitch: (Double) -> Unit
) {

    private var isRunning = false
    private var audioRecord: AudioRecord? = null

    private val sampleRate = 22050
    private val bufferSize = 2048

    /// 🎤 START MIC
    fun startMic() {
        if (isRunning) return

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
            maxOf(minBuffer, bufferSize)
        )

        audioRecord?.startRecording()
        isRunning = true

        Thread {
            val buffer = ShortArray(bufferSize)

            while (isRunning) {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                if (read <= 0) continue

                val pitch = detectPitch(buffer, read)
                onPitch(pitch)
            }
        }.start()
    }

    /// 🎵 START MP3 FILE (DECODE + PROCESS)
    fun startFile(path: String) {
        if (isRunning) return
        isRunning = true

        Thread {
            try {
                val extractor = MediaExtractor()
                extractor.setDataSource(path)

                var format: MediaFormat? = null
                var trackIndex = -1

                for (i in 0 until extractor.trackCount) {
                    val f = extractor.getTrackFormat(i)
                    val mime = f.getString(MediaFormat.KEY_MIME)
                    if (mime!!.startsWith("audio/")) {
                        format = f
                        trackIndex = i
                        break
                    }
                }

                if (trackIndex == -1) return@Thread

                extractor.selectTrack(trackIndex)

                val mime = format!!.getString(MediaFormat.KEY_MIME)!!
                val codec = MediaCodec.createDecoderByType(mime)
                codec.configure(format, null, null, 0)
                codec.start()

                val inputBuffers = codec.inputBuffers
                val outputBuffers = codec.outputBuffers
                val bufferInfo = MediaCodec.BufferInfo()

                var isEOS = false

                while (isRunning) {

                    if (!isEOS) {
                        val inIndex = codec.dequeueInputBuffer(10000)
                        if (inIndex >= 0) {
                            val buffer = inputBuffers[inIndex]
                            val sampleSize = extractor.readSampleData(buffer, 0)

                            if (sampleSize < 0) {
                                codec.queueInputBuffer(
                                    inIndex, 0, 0, 0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                isEOS = true
                            } else {
                                codec.queueInputBuffer(
                                    inIndex, 0, sampleSize,
                                    extractor.sampleTime, 0
                                )
                                extractor.advance()
                            }
                        }
                    }

                    val outIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)

                    if (outIndex >= 0) {
                        val outBuffer = outputBuffers[outIndex]

                        val chunk = ShortArray(bufferInfo.size / 2)
                        outBuffer.asShortBuffer().get(chunk)

                        val pitch = detectPitch(chunk, chunk.size)
                        onPitch(pitch)

                        codec.releaseOutputBuffer(outIndex, false)
                    }

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        break
                    }
                }

                codec.stop()
                codec.release()
                extractor.release()

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    fun stop() {
        isRunning = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }

    /// 🎯 PITCH DETECTION (UNCHANGED)
    private fun detectPitch(buffer: ShortArray, size: Int): Double {

        var sum = 0.0
        for (i in 0 until size) {
            sum += buffer[i] * buffer[i]
        }

        val rms = sqrt(sum / size)
        if (rms < 1000) return 0.0

        val minFreq = 80.0
        val maxFreq = 1000.0

        val minLag = (sampleRate / maxFreq).toInt()
        val maxLag = (sampleRate / minFreq).toInt()

        var bestLag = 0
        var maxCorr = 0.0

        for (lag in minLag..maxLag) {

            var corr = 0.0

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