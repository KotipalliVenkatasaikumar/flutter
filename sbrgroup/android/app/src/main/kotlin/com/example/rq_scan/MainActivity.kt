package com.example.ajna

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val METHOD_CHANNEL = "emergency_audio_channel"
private const val EMERGENCY_CHANNEL_ID = "emergency_channel"
private const val DEFAULT_CHANNEL_ID = "default_channel"

class MainActivity : FlutterActivity() {
    private var mediaPlayer: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler {
                call, result ->
            when (call.method) {
                "playEmergencySound" -> {
                    playEmergencySound()
                    result.success(null)
                }
                "stopEmergencySound" -> {
                    stopEmergencySound()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)

            // Emergency channel
            val emergencySound = Uri.parse("android.resource://$packageName/raw/emergency_tone")
            val emergencyAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val emergencyChannel = NotificationChannel(
                EMERGENCY_CHANNEL_ID,
                "Emergency Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Used for emergency alerts"
                setSound(emergencySound, emergencyAttributes)
            }

            // Default channel
            val defaultChannel = NotificationChannel(
                DEFAULT_CHANNEL_ID,
                "Default Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Used for normal notifications"
               
            }

            notificationManager?.createNotificationChannel(emergencyChannel)
            notificationManager?.createNotificationChannel(defaultChannel)
        }
    }

    private fun playEmergencySound() {
        if (mediaPlayer == null) {
            mediaPlayer = MediaPlayer().apply {
                val afd = resources.openRawResourceFd(R.raw.emergency_tone)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepareAsync()
                setOnPreparedListener { start() }
            }
        } else if (!mediaPlayer!!.isPlaying) {
            mediaPlayer?.start()
        }
    }

    private fun stopEmergencySound() {
        mediaPlayer?.apply {
            if (isPlaying) stop()
            release()
        }
        mediaPlayer = null
    }

    override fun onDestroy() {
        stopEmergencySound()
        super.onDestroy()
    }
}
