package com.example.chunktool

import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import rikka.shizuku.Shizuku
import java.io.File

class NativeBridgePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var activityBinding: ActivityPluginBinding? = null

    private var shizukuService: IShizukuUserService? = null
    private var pendingShizukuListResult: Result? = null

    private val permissionListener = Shizuku.OnRequestPermissionResultListener { _, _ ->
        // O Flutter reconsulta hasShizuku() quando o app volta ao primeiro plano,
        // entao nao precisamos fazer nada aqui alem de deixar o listener registrado.
    }

    private val userServiceArgs = Shizuku.UserServiceArgs(
        ComponentName(BuildConfigPackage, ShizukuUserService::class.java.name)
    )
        .daemon(false)
        .processNameSuffix("shizuku_service")
        .debuggable(false)
        .version(1)

    private val userServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            if (binder == null || !binder.pingBinder()) {
                pendingShizukuListResult?.success(null)
                pendingShizukuListResult = null
                return
            }
            shizukuService = IShizukuUserService.Stub.asInterface(binder)
            val worlds = try {
                shizukuService?.listWorlds() ?: ""
            } catch (e: Exception) {
                ""
            }
            pendingShizukuListResult?.success(worlds)
            pendingShizukuListResult = null
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            shizukuService = null
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        Shizuku.addRequestPermissionResultListener(permissionListener)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        Shizuku.removeRequestPermissionResultListener(permissionListener)
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
            "hasShizuku" -> result.success(hasShizuku())
            "requestShizukuPermission" -> {
                requestShizukuPermission()
                result.success(null)
            }
            "listWorldsShizuku" -> {
                pendingShizukuListResult = result
                bindShizukuService()
            }
            else -> result.notImplemented()
        }
    }

    // ---------- Armazenamento comum (pasta legada/publica) ----------

    private fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
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

    // ---------- Shizuku (pasta protegida) ----------

    private fun hasShizuku(): Boolean {
        if (!Shizuku.pingBinder()) return false
        return Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
    }

    private fun requestShizukuPermission() {
        if (!Shizuku.pingBinder()) return
        if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
            Shizuku.requestPermission(SHIZUKU_REQUEST_CODE)
        }
    }

    private fun bindShizukuService() {
        if (!hasShizuku()) {
            pendingShizukuListResult?.success(null)
            pendingShizukuListResult = null
            return
        }
        try {
            Shizuku.bindUserService(userServiceArgs, userServiceConnection)
        } catch (e: Exception) {
            pendingShizukuListResult?.success(null)
            pendingShizukuListResult = null
        }
    }

    companion object {
        const val CHANNEL_NAME = "chunk_tool/native"
        const val SHIZUKU_REQUEST_CODE = 1001
        const val BuildConfigPackage = "com.example.chunktool"
    }
}
