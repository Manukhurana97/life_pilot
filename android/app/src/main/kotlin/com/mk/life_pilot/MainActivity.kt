package com.mk.life_pilot

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mk.life_pilot/battery"
    private val FILE_CHANNEL = "com.mk.life_pilot/file"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            var intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "openBatterySettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "getManufacturer" -> {
                        result.success(Build.MANUFACTURER.lowercase())
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDownloadPath" -> {
                        try {
                            val dir = Environment.getExternalStoragePublicDirectory(
                                Environment.DIRECTORY_DOWNLOADS
                            )
                            dir.mkdirs()
                            result.success(dir.absolutePath)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Download folder not available", null)
                        }
                    }

                    "openFileLocation" -> {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW)
                            val uri = Uri.parse(
                                "content://com.android.externalstorage.documents/document/primary:Download"
                            )

                            intent.setDataAndType(uri, "vnd.android.document/directory")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Intent.ACTION_GET_CONTENT)
                                intent.type = "*/*"

                                startActivity(Intent.createChooser(intent, "Open Downloads"))
                                result.success(true)
                            } catch (e2: Exception) {
                                result.success(false)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
