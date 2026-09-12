package com.example.chunktool

import java.nio.ByteBuffer
import java.nio.ByteOrder

data class ChunkCoord(val x: Int, val z: Int, val dimension: Int)

object ChunkScanner {

    data class ScanResult(val success: Boolean, val error: String?, val chunks: List<ChunkCoord>)
    data class DeleteResult(val success: Boolean, val error: String?, val deletedCount: Int)

    fun scan(worldPath: String): ScanResult {
        val db = NativeLevelDB()
        val handle = db.nativeOpen("$worldPath/db")
        if (handle == 0L) {
            return ScanResult(success = false, error = db.nativeLastError(), chunks = emptyList())
        }

        val chunks = mutableSetOf<ChunkCoord>()
        val iter = db.nativeCreateIterator(handle)
        db.nativeIteratorSeekToFirst(iter)
        while (db.nativeIteratorValid(iter)) {
            val key = db.nativeIteratorKey(iter)
            parseChunkCoord(key)?.let { chunks.add(it) }
            db.nativeIteratorNext(iter)
        }
        db.nativeIteratorClose(iter)
        db.nativeClose(handle)

        return ScanResult(success = true, error = null, chunks = chunks.toList())
    }

    private fun parseChunkCoord(key: ByteArray): ChunkCoord? {
        if (key.size < 9 || key.size > 14) return null
        val buffer = ByteBuffer.wrap(key).order(ByteOrder.LITTLE_ENDIAN)
        return try {
            val x = buffer.int
            val z = buffer.int
            when (key.size) {
                9, 10 -> ChunkCoord(x, z, 0)
                13, 14 -> {
                    val dim = buffer.int
                    ChunkCoord(x, z, dim)
                }
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }

    fun deleteChunks(worldPath: String, chunks: List<ChunkCoord>): DeleteResult {
        val db = NativeLevelDB()
        val handle = db.nativeOpen("$worldPath/db")
        if (handle == 0L) {
            return DeleteResult(success = false, error = db.nativeLastError(), deletedCount = 0)
        }

        var totalDeleted = 0
        for (chunk in chunks) {
            val prefix = buildPrefix(chunk.x, chunk.z, chunk.dimension)
            val iter = db.nativeCreateIterator(handle)
            db.nativeIteratorSeek(iter, prefix)
            while (db.nativeIteratorValid(iter)) {
                val key = db.nativeIteratorKey(iter)
                if (!keyStartsWith(key, prefix)) break
                db.nativeDelete(handle, key)
                totalDeleted++
                db.nativeIteratorNext(iter)
            }
            db.nativeIteratorClose(iter)
        }
        db.nativeClose(handle)

        return DeleteResult(success = true, error = null, deletedCount = totalDeleted)
    }

    private fun buildPrefix(x: Int, z: Int, dimension: Int): ByteArray {
        val buffer = if (dimension == 0) {
            ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN)
        } else {
            ByteBuffer.allocate(12).order(ByteOrder.LITTLE_ENDIAN)
        }
        buffer.putInt(x)
        buffer.putInt(z)
        if (dimension != 0) {
            buffer.putInt(dimension)
        }
        return buffer.array()
    }

    private fun keyStartsWith(key: ByteArray, prefix: ByteArray): Boolean {
        if (key.size < prefix.size) return false
        for (i in prefix.indices) {
            if (key[i] != prefix[i]) return false
        }
        return true
    }

    /// Le os blocos do topo (256 colunas) de um chunk especifico. Serve pra
    /// testar se a decodificacao do formato binario ta certa, antes de montar
    /// o mapa visual.
    fun getTopBlocks(worldPath: String, chunk: ChunkCoord): List<String> {
        val db = NativeLevelDB()
        val handle = db.nativeOpen("$worldPath/db")
        if (handle == 0L) return emptyList()
        val raw = db.nativeGetTopBlocks(handle, chunk.x, chunk.z, chunk.dimension)
        db.nativeClose(handle)
        return raw.split(";")
    }
}
