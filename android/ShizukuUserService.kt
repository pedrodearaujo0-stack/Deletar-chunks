package com.example.chunktool

import java.io.File

/**
 * Este codigo roda num PROCESSO SEPARADO, com a identidade do shell
 * (fornecida pelo Shizuku). E por isso que ele consegue acessar
 * Android/data/com.mojang.minecraftpe, mesmo quando o app principal nao consegue.
 */
class ShizukuUserService : IShizukuUserService.Stub() {

    private val worldsDir = File(
        "/storage/emulated/0/Android/data/com.mojang.minecraftpe/files/games/com.mojang/minecraftWorlds"
    )

    override fun listWorlds(): String {
        if (!worldsDir.exists() || !worldsDir.isDirectory) return ""
        val names = worldsDir.listFiles()
            ?.filter { it.isDirectory && File(it, "level.dat").exists() }
            ?.map { it.name }
            ?: emptyList()
        return names.joinToString("\n")
    }

    override fun copyWorldToStaging(worldFolderName: String, stagingPath: String): Boolean {
        return try {
            val source = File(worldsDir, worldFolderName)
            val dest = File(stagingPath)
            dest.deleteRecursively()
            source.copyRecursively(dest, overwrite = true)
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun copyStagingBackToWorld(worldFolderName: String, stagingPath: String): Boolean {
        return try {
            val source = File(stagingPath)
            val dest = File(worldsDir, worldFolderName)
            source.copyRecursively(dest, overwrite = true)
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun destroy() {
        System.exit(0)
    }
}
