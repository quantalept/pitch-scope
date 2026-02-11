package com.quantalept.pitchscope

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "live_audio_stream"

    private lateinit var channel: MethodChannel
    private lateinit var audioEngine: AudioEngine

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        audioEngine = AudioEngine { pitch ->

            // 🔥 MUST run on main thread
            runOnUiThread {
                channel.invokeMethod("pitch", pitch)
            }
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startAudio()
                    result.success(null)
                }
                "stop" -> {
                    audioEngine.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startAudio() {
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

        audioEngine.start()
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
            audioEngine.start()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        audioEngine.stop()
    }
}
