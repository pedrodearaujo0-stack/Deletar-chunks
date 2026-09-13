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
                9, 10 -> {
                    val tag = key[8].toInt() and 0xFF
                    if (!isKnownChunkTag(tag)) return null
                    ChunkCoord(x, z, 0)
                }
                13, 14 -> {
                    val dim = buffer.int
                    val tag = key[12].toInt() and 0xFF
                    if (!isKnownChunkTag(tag)) return null
                    if (dim != 1 && dim != 2) return null
                    ChunkCoord(x, z, dim)
                }
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }

    // Tags conhecidos de dado de chunk de verdade (terreno, entidades, etc.),
    // conforme o formato documentado do Bedrock. Filtra chaves de outros
    // tipos (jogador, atores, etc.) que por acaso tem o mesmo tamanho.
    private fun isKnownChunkTag(tag: Int): Boolean {
        return (tag in 43..64) || tag == 118
    }

    fun deleteChunks(worldPath: String, chunks: List<ChunkCoord>): DeleteResult {
        val db = NativeLevelDB()
        val handle = db.nativeOpen("$worldPath/db")
        if (handle == 0L) {
            return DeleteResult(success = false, error = db.nativeLastError(), deletedCount = 0)
        }

        var totalDeleted = 0
        for (chunk in chunks) {
            // Limpa as entidades (mobs, itens no chao, etc.) associadas a esse
            // chunk primeiro — elas ficam numa parte separada do banco, entao
            // apagar so o terreno nao remove elas.
            val digpKey = buildDigpKey(chunk.x, chunk.z, chunk.dimension)
            val digpValue = db.nativeGet(handle, digpKey)
            if (digpValue != null) {
                var offset = 0
                while (offset + 8 <= digpValue.size) {
                    val actorId = digpValue.copyOfRange(offset, offset + 8)
                    db.nativeDelete(handle, buildActorKey(actorId))
                    totalDeleted++
                    offset += 8
                }
                db.nativeDelete(handle, digpKey)
                totalDeleted++
            }

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

    private fun buildDigpKey(x: Int, z: Int, dimension: Int): ByteArray {
        val prefix = "digp".toByteArray(Charsets.US_ASCII)
        val buffer = if (dimension == 0) {
            ByteBuffer.allocate(prefix.size + 8).order(ByteOrder.LITTLE_ENDIAN)
        } else {
            ByteBuffer.allocate(prefix.size + 12).order(ByteOrder.LITTLE_ENDIAN)
        }
        buffer.put(prefix)
        buffer.putInt(x)
        buffer.putInt(z)
        if (dimension != 0) {
            buffer.putInt(dimension)
        }
        return buffer.array()
    }

    private fun buildActorKey(id: ByteArray): ByteArray {
        return "actorprefix".toByteArray(Charsets.US_ASCII) + id
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

    /// Le o bloco do topo (so a coluna central) de varios chunks de uma vez,
    /// abrindo o banco uma unica vez. Usado pra colorir o mapa.
    fun getChunkColors(worldPath: String, chunks: List<ChunkCoord>): Map<ChunkCoord, String> {
        val db = NativeLevelDB()
        val handle = db.nativeOpen("$worldPath/db")
        if (handle == 0L) return emptyMap()

        val result = mutableMapOf<ChunkCoord, String>()
        for (chunk in chunks) {
            val block = db.nativeGetChunkTopBlock(handle, chunk.x, chunk.z, chunk.dimension)
            result[chunk] = block
        }
        db.nativeClose(handle)
        return result
    }
}
