package com.example.chunktool

data class FieldLocation(val offset: Int, val isInt: Boolean)

data class WorldEditState(val flags: Map<String, Boolean>, val gameType: Int)

object LevelDatEditor {

    private val TARGET_BYTE_FIELDS = setOf("cheatsEnabled", "commandsEnabled", "hasBeenLoadedInCreative")
    private val TARGET_INT_FIELDS = setOf("GameType")

    fun readState(worldPath: String): WorldEditState? {
        val file = java.io.File(worldPath, "level.dat")
        if (!file.exists()) return null
        val bytes = file.readBytes()
        val fields = scanFields(bytes) ?: return null

        val flags = mutableMapOf<String, Boolean>()
        var gameType = 0
        for ((name, loc) in fields) {
            if (loc.isInt) {
                if (name == "GameType") gameType = readI32(bytes, loc.offset)
            } else {
                flags[name] = bytes[loc.offset].toInt() != 0
            }
        }
        return WorldEditState(flags, gameType)
    }

    fun writeFlags(worldPath: String, flags: Map<String, Boolean>): Boolean {
        val file = java.io.File(worldPath, "level.dat")
        if (!file.exists()) return false
        val bytes = file.readBytes()
        val fields = scanFields(bytes) ?: return false
        var changed = false
        for ((name, loc) in fields) {
            if (loc.isInt) continue
            val newValue = flags[name] ?: continue
            bytes[loc.offset] = if (newValue) 1 else 0
            changed = true
        }
        if (changed) file.writeBytes(bytes)
        return changed
    }

    // gameType: 0 = Sobrevivencia, 1 = Criativo, 2 = Aventura
    fun writeGameType(worldPath: String, gameType: Int): Boolean {
        val file = java.io.File(worldPath, "level.dat")
        if (!file.exists()) return false
        val bytes = file.readBytes()
        val fields = scanFields(bytes) ?: return false
        val loc = fields["GameType"] ?: return false
        if (!loc.isInt) return false
        writeI32(bytes, loc.offset, gameType)
        file.writeBytes(bytes)
        return true
    }

    // Acha a posicao (offset) de cada campo alvo dentro do arquivo bruto,
    // percorrendo a estrutura NBT do level.dat.
    private fun scanFields(bytes: ByteArray): Map<String, FieldLocation>? {
        // level.dat = 4 bytes versao + 4 bytes tamanho + payload NBT
        if (bytes.size < 8) return null
        var offset = 8

        val rootType = bytes[offset].toInt() and 0xFF
        offset += 1
        if (rootType != 10) return null // deveria ser TAG_Compound

        offset = skipString(bytes, offset) // nome da raiz, normalmente vazio

        val result = mutableMapOf<String, FieldLocation>()
        while (offset < bytes.size) {
            val tagType = bytes[offset].toInt() and 0xFF
            offset += 1
            if (tagType == 0) break // TAG_End

            val nameStart = offset
            offset = skipString(bytes, offset)
            val fieldName = String(bytes, nameStart + 2, offset - nameStart - 2, Charsets.UTF_8)

            if (tagType == 1 && fieldName in TARGET_BYTE_FIELDS) {
                result[fieldName] = FieldLocation(offset, isInt = false)
                offset += 1
            } else if (tagType == 3 && fieldName in TARGET_INT_FIELDS) {
                result[fieldName] = FieldLocation(offset, isInt = true)
                offset += 4
            } else {
                offset = skipValue(bytes, offset, tagType) ?: return null
            }
        }
        return result
    }

    private fun skipString(bytes: ByteArray, offset: Int): Int {
        val len = readU16(bytes, offset)
        return offset + 2 + len
    }

    private fun readU16(bytes: ByteArray, offset: Int): Int {
        return (bytes[offset].toInt() and 0xFF) or ((bytes[offset + 1].toInt() and 0xFF) shl 8)
    }

    private fun readI32(bytes: ByteArray, offset: Int): Int {
        return (bytes[offset].toInt() and 0xFF) or
            ((bytes[offset + 1].toInt() and 0xFF) shl 8) or
            ((bytes[offset + 2].toInt() and 0xFF) shl 16) or
            ((bytes[offset + 3].toInt() and 0xFF) shl 24)
    }

    private fun writeI32(bytes: ByteArray, offset: Int, value: Int) {
        bytes[offset] = (value and 0xFF).toByte()
        bytes[offset + 1] = ((value shr 8) and 0xFF).toByte()
        bytes[offset + 2] = ((value shr 16) and 0xFF).toByte()
        bytes[offset + 3] = ((value shr 24) and 0xFF).toByte()
    }

    private fun skipValue(bytes: ByteArray, offsetIn: Int, tagType: Int): Int? {
        var offset = offsetIn
        return when (tagType) {
            1 -> offset + 1
            2 -> offset + 2
            3 -> offset + 4
            4 -> offset + 8
            5 -> offset + 4
            6 -> offset + 8
            7 -> {
                val len = readI32(bytes, offset)
                offset + 4 + len
            }
            8 -> skipString(bytes, offset)
            9 -> {
                val itemType = bytes[offset].toInt() and 0xFF
                offset += 1
                val count = readI32(bytes, offset)
                offset += 4
                for (i in 0 until count) {
                    offset = skipValue(bytes, offset, itemType) ?: return null
                }
                offset
            }
            10 -> {
                while (true) {
                    val innerType = bytes[offset].toInt() and 0xFF
                    offset += 1
                    if (innerType == 0) break
                    offset = skipString(bytes, offset)
                    offset = skipValue(bytes, offset, innerType) ?: return null
                }
                offset
            }
            11 -> {
                val len = readI32(bytes, offset)
                offset + 4 + len * 4
            }
            12 -> {
                val len = readI32(bytes, offset)
                offset + 4 + len * 8
            }
            else -> null
        }
    }
}
