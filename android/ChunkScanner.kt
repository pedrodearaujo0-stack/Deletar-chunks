package com.example.chunktool

import java.nio.ByteBuffer
import java.nio.ByteOrder

data class ChunkCoord(val x: Int, val z: Int, val dimension: Int)

object ChunkScanner {

    data class ScanResult(val success: Boolean, val error: String?, val chunks: List<ChunkCoord>)

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
}
