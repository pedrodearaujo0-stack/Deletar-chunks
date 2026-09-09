package com.example.chunktool

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

class NativeBridgePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "hasStoragePermission" -> result.success(hasStoragePermission())
            "requestStoragePermission" -> {
                requestStoragePermission()
                result.success(null)
            }
            "listWorlds" -> result.success(listWorlds())
            else -> result.notImplemented()
        }
    }

    private fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true // versões antigas não usam MANAGE_EXTERNAL_STORAGE
        }
    }

    private fun requestStoragePermission() {
        val activity = activityBinding?.activity ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
            intent.data = Uri.parse("package:${activity.packageName}")
            activity.startActivity(intent)
        }
    }

    private fun listWorlds(): List<Map<String, String>> {
        val worldsDir = findWorldsDir() ?: return emptyList()
        val worlds = mutableListOf<Map<String, String>>()
        worldsDir.listFiles()?.forEach { folder ->
            if (folder.isDirectory && File(folder, "level.dat").exists()) {
                worlds.add(
                    mapOf(
                        "folderName" to folder.name,
                        "path" to folder.absolutePath
                    )
                )
            }
        }
        return worlds
    }

    private fun findWorldsDir(): File? {
        val candidates = listOf(
            "/storage/emulated/0/Android/data/com.mojang.minecraftpe/files/games/com.mojang/minecraftWorlds",
            "/storage/emulated/0/games/com.mojang/minecraftWorlds"
        )
        return candidates.map { File(it) }.firstOrNull { it.exists() && it.isDirectory }
    }

    companion object {
        const val CHANNEL_NAME = "chunk_tool/native"
    }
}
