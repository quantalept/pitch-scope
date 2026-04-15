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

    private lateinit var userAudioEngine: AudioEngine
    private lateinit var mp3AudioEngine: AudioEngine

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        /// 🎤 USER MIC
        userAudioEngine = AudioEngine { pitch ->
            runOnUiThread {
                channel.invokeMethod("userPitch", pitch)
            }
        }

        /// 🎵 MP3 REAL-TIME STREAM
        mp3AudioEngine = AudioEngine { pitch ->
            runOnUiThread {
                channel.invokeMethod("mp3Pitch", pitch)
            }
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {

                /// 🎤 START MIC
                "startUser" -> {
                    startMic()
                    result.success(null)
                }

                /// 🎤 STOP MIC
                "stopUser" -> {
                    userAudioEngine.stop()
                    result.success(null)
                }

                /// 🎵 START MP3 STREAM
                "startMP3" -> {
                    val path = call.argument<String>("asset")
                    if (path != null) {
                        mp3AudioEngine.startFile(path)
                        result.success(null)
                    } else {
                        result.error("NO_PATH", "Path is null", null)
                    }
                }

                /// 🎵 STOP MP3 STREAM
                "stopMP3" -> {
                    mp3AudioEngine.stop()
                    result.success(null)
                }

                /// 🔥 SAFE FULL SONG PITCH EXTRACTION
                "extractPitchFromFile" -> {

                    val path = call.argument<String>("path")

                    if (path == null) {
                        result.error("NO_PATH", "Path is null", null)
                        return@setMethodCallHandler
                    }

                    val pitchList = mutableListOf<Double>()
                    var isCollecting = true

                    /// TEMP ENGINE
                    val tempEngine = AudioEngine { pitch ->
                        if (pitch > 0 && isCollecting) {
                            synchronized(pitchList) {
                                pitchList.add(pitch)
                            }
                        }
                    }

                    Thread {
                        try {
                            tempEngine.startFile(path)

                            /// ⏱️ WAIT (can improve later with callback)
                            Thread.sleep(5000)

                            /// 🛑 STOP SAFELY
                            isCollecting = false
                            tempEngine.stop()

                            /// ✅ CREATE SAFE COPY (NO CRASH)
                            val safeList = synchronized(pitchList) {
                                ArrayList(pitchList)
                            }

                            runOnUiThread {
                                result.success(safeList)
                            }

                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("ERROR", e.message, null)
                            }
                        }
                    }.start()
                }

                else -> result.notImplemented()
            }
        }
    }

    /// 🎤 MIC PERMISSION HANDLING
    private fun startMic() {
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

        userAudioEngine.startMic()
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
            userAudioEngine.startMic()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        userAudioEngine.stop()
        mp3AudioEngine.stop()
    }
}