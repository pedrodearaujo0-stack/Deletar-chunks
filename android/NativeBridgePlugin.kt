package com.example.chunktool

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.provider.Settings
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import rikka.shizuku.Shizuku
import java.io.File
import java.util.zip.ZipInputStream

class NativeBridgePlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var activityBinding: ActivityPluginBinding? = null

    private var shizukuService: IShizukuUserService? = null
    private var pendingShizukuListResult: Result? = null
    private var pendingFolderPickResult: Result? = null
    private var pendingFilePickResult: Result? = null

    private val permissionListener = Shizuku.OnRequestPermissionResultListener { _, _ -> }

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
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == FOLDER_PICK_REQUEST_CODE) {
            val context = activityBinding?.activity?.applicationContext
            if (resultCode == Activity.RESULT_OK && data?.data != null && context != null) {
                val treeUri = data.data!!
                try {
                    context.contentResolver.takePersistableUriPermission(
                        treeUri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                } catch (e: Exception) {
                    // segue mesmo se nao conseguir persistir, vale pra sessao atual
                }
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .edit()
                    .putString(PREF_KEY_TREE_URI, treeUri.toString())
                    .apply()
                pendingFolderPickResult?.success(true)
            } else {
                pendingFolderPickResult?.success(false)
            }
            pendingFolderPickResult = null
            return true
        }

        if (requestCode == FILE_PICK_REQUEST_CODE) {
            val context = activityBinding?.activity?.applicationContext
            if (resultCode == Activity.RESULT_OK && data?.data != null && context != null) {
                val fileUri = data.data!!
                val worldInfo = extractMcworldToStaging(context, fileUri)
                pendingFilePickResult?.success(worldInfo)
            } else {
                pendingFilePickResult?.success(null)
            }
            pendingFilePickResult = null
            return true
        }

        return false
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
            "pickFolder" -> {
                pendingFolderPickResult = result
                pickFolder()
            }
            "hasPickedFolder" -> result.success(getSavedTreeUri() != null)
            "listWorldsInPickedFolder" -> result.success(listWorldsInPickedFolder())
            "pickWorldFile" -> {
                pendingFilePickResult = result
                pickWorldFile()
            }
            "scanChunks" -> {
                val worldPath = call.argument<String>("worldPath")
                if (worldPath == null) {
                    result.success(mapOf("success" to false, "error" to "worldPath ausente"))
                } else {
                    scanChunksAsync(worldPath, result)
                }
            }
            "deleteChunks" -> {
                val worldPath = call.argument<String>("worldPath")
                val chunksArg = call.argument<List<Map<String, Any>>>("chunks")
                if (worldPath == null || chunksArg == null) {
                    result.success(mapOf("success" to false, "error" to "argumentos ausentes"))
                } else {
                    val chunks = chunksArg.map {
                        ChunkCoord(
                            x = (it["x"] as Number).toInt(),
                            z = (it["z"] as Number).toInt(),
                            dimension = (it["dimension"] as Number).toInt()
                        )
                    }
                    deleteChunksAsync(worldPath, chunks, result)
                }
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

    // ---------- Pasta escolhida manualmente pelo usuario ----------

    private fun pickFolder() {
        val activity = activityBinding?.activity
        if (activity == null) {
            pendingFolderPickResult?.success(false)
            pendingFolderPickResult = null
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        intent.addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        )
        activity.startActivityForResult(intent, FOLDER_PICK_REQUEST_CODE)
    }

    private fun getSavedTreeUri(): Uri? {
        val context = activityBinding?.activity?.applicationContext ?: return null
        val saved = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(PREF_KEY_TREE_URI, null) ?: return null
        return Uri.parse(saved)
    }

    private fun listWorldsInPickedFolder(): List<Map<String, String>> {
        val context = activityBinding?.activity?.applicationContext ?: return emptyList()
        val treeUri = getSavedTreeUri() ?: return emptyList()
        val root = DocumentFile.fromTreeUri(context, treeUri) ?: return emptyList()

        val worlds = mutableListOf<Map<String, String>>()
        root.listFiles().forEach { folder ->
            if (folder.isDirectory && folder.findFile("level.dat") != null) {
                worlds.add(
                    mapOf(
                        "folderName" to (folder.name ?: "?"),
                        "path" to "Pasta escolhida"
                    )
                )
            }
        }
        return worlds
    }

    // ---------- Arquivo .mcworld escolhido diretamente ----------

    private fun pickWorldFile() {
        val activity = activityBinding?.activity
        if (activity == null) {
            pendingFilePickResult?.success(null)
            pendingFilePickResult = null
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.type = "*/*"
        activity.startActivityForResult(intent, FILE_PICK_REQUEST_CODE)
    }

    private fun extractMcworldToStaging(context: Context, fileUri: Uri): Map<String, String>? {
        return try {
            val displayName = queryDisplayName(context, fileUri) ?: "mundo_importado"
            val safeName = displayName.substringBeforeLast(".").ifBlank { "mundo_importado" }

            val stagingRoot = File(context.getExternalFilesDir(null), "imported_worlds/$safeName")
            stagingRoot.deleteRecursively()
            stagingRoot.mkdirs()

            context.contentResolver.openInputStream(fileUri)?.use { input ->
                ZipInputStream(input).use { zip ->
                    var entry = zip.nextEntry
                    while (entry != null) {
                        val outFile = File(stagingRoot, entry.name)
                        if (entry.isDirectory) {
                            outFile.mkdirs()
                        } else {
                            outFile.parentFile?.mkdirs()
                            outFile.outputStream().use { output -> zip.copyTo(output) }
                        }
                        zip.closeEntry()
                        entry = zip.nextEntry
                    }
                }
            } ?: return null

            if (!File(stagingRoot, "level.dat").exists()) {
                // as vezes o .mcworld tem uma subpasta interna em vez do level.dat na raiz
                val inner = stagingRoot.listFiles()?.firstOrNull {
                    it.isDirectory && File(it, "level.dat").exists()
                }
                if (inner != null) {
                    return mapOf(
                        "folderName" to safeName,
                        "path" to inner.absolutePath
                    )
                }
                return null
            }

            mapOf(
                "folderName" to safeName,
                "path" to stagingRoot.absolutePath
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun queryDisplayName(context: Context, uri: Uri): String? {
        return try {
            context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (cursor.moveToFirst() && nameIndex >= 0) cursor.getString(nameIndex) else null
            }
        } catch (e: Exception) {
            null
        }
    }

    // ---------- Varredura de chunks (LevelDB nativo) ----------

    private fun scanChunksAsync(worldPath: String, result: Result) {
        val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
        Thread {
            val scanResult = try {
                ChunkScanner.scan(worldPath)
            } catch (e: Throwable) {
                ChunkScanner.ScanResult(false, "Excecao: ${e.message}", emptyList())
            }
            mainHandler.post {
                result.success(
                    mapOf(
                        "success" to scanResult.success,
                        "error" to scanResult.error,
                        "chunks" to scanResult.chunks.map {
                            mapOf("x" to it.x, "z" to it.z, "dimension" to it.dimension)
                        }
                    )
                )
            }
        }.start()
    }

    private fun deleteChunksAsync(worldPath: String, chunks: List<ChunkCoord>, result: Result) {
        val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
        Thread {
            val deleteResult = try {
                ChunkScanner.deleteChunks(worldPath, chunks)
            } catch (e: Throwable) {
                ChunkScanner.DeleteResult(false, "Excecao: ${e.message}", 0)
            }
            mainHandler.post {
                result.success(
                    mapOf(
                        "success" to deleteResult.success,
                        "error" to deleteResult.error,
                        "deletedCount" to deleteResult.deletedCount
                    )
                )
            }
        }.start()
    }

    companion object {
        const val CHANNEL_NAME = "chunk_tool/native"
        const val SHIZUKU_REQUEST_CODE = 1001
        const val FOLDER_PICK_REQUEST_CODE = 2001
        const val FILE_PICK_REQUEST_CODE = 3001
        const val BuildConfigPackage = "com.example.chunktool"
        const val PREFS_NAME = "chunk_tool_prefs"
        const val PREF_KEY_TREE_URI = "picked_tree_uri"
    }
    }
    
