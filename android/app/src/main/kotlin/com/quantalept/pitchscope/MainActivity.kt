package com.quantalept.pitchscope

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlin.math.*

class MainActivity : FlutterActivity() {

    private val CHANNEL = "live_audio_stream"

    private var audioRecord: AudioRecord? = null
    private var audioJob: Job? = null
    private var isRunning = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startAudio(flutterEngine)
                    result.success(null)
                }
                "stop" -> {
                    stopAudio()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startAudio(flutterEngine: FlutterEngine) {
        if (isRunning) return

        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                1001
            )
            return
        }

        val sampleRate = 44100
        val bufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        audioRecord?.startRecording()
        isRunning = true

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        audioJob = CoroutineScope(Dispatchers.Default).launch {
            val buffer = ShortArray(bufferSize)

            while (isRunning) {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                if (read <= 0) continue

                // Mic level (RMS)
                var sum = 0.0
                for (i in 0 until read) {
                    sum += buffer[i] * buffer[i]
                }
                val rms = sqrt(sum / read)
                val level = (rms / 32768.0).coerceIn(0.0, 1.0)

                // Pitch (auto-correlation)
                val pitch = estimatePitch(buffer, sampleRate)

                withContext(Dispatchers.Main) {
                    channel.invokeMethod("level", level)
                    if (pitch in 60.0..3000.0) {
                        channel.invokeMethod("pitch", pitch)
                    }
                }
            }
        }
    }

    private fun stopAudio() {
        isRunning = false
        audioJob?.cancel()
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }

    private fun estimatePitch(buffer: ShortArray, sampleRate: Int): Double {
        var bestLag = 0
        var maxCorr = 0.0

        for (lag in 40..2000) {
            var corr = 0.0
            for (i in 0 until buffer.size - lag) {
                corr += buffer[i] * buffer[i + lag]
            }
            if (corr > maxCorr) {
                maxCorr = corr
                bestLag = lag
            }
        }

        return if (bestLag > 0)
            sampleRate.toDouble() / bestLag
        else
            0.0
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == 1001 &&
            grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            startAudio(flutterEngine!!)
        }
    }
}
