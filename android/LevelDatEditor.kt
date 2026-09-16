package com.example.chunktool

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

object LevelDatEditor {

    private val TARGET_FIELDS = setOf("cheatsEnabled", "commandsEnabled", "hasBeenLoadedInCreative")

    fun readFlags(worldPath: String): Map<String, Boolean>? {
        val file = File(worldPath, "level.dat")
        if (!file.exists()) return null
        val bytes = file.readBytes()
        val offsets = scanTopLevelByteFields(bytes) ?: return null
        val result = mutableMapOf<String, Boolean>()
        for ((name, offset) in offsets) {
            result[name] = bytes[offset].toInt() != 0
        }
        return result
    }

    fun writeFlags(worldPath: String, flags: Map<String, Boolean>): Boolean {
        val file = File(worldPath, "level.dat")
        if (!file.exists()) return false
        val bytes = file.readBytes()
        val offsets = scanTopLevelByteFields(bytes) ?: return false
        var changed = false
        for ((name, offset) in offsets) {
            val newValue = flags[name] ?: continue
            bytes[offset] = if (newValue) 1 else 0
            changed = true
        }
        if (changed) {
            file.writeBytes(bytes)
        }
        return changed
    }

    // Acha a posicao (offset) de cada campo alvo dentro do arquivo bruto,
    // percorrendo a estrutura NBT do level.dat.
    private fun scanTopLevelByteFields(bytes: ByteArray): Map<String, Int>? {
        // level.dat = 4 bytes versao + 4 bytes tamanho + payload NBT
        if (bytes.size < 8) return null
        var offset = 8

        val rootType = bytes[offset].toInt() and 0xFF
        offset += 1
        if (rootType != 10) return null // deveria ser TAG_Compound

        offset = skipString(bytes, offset) // nome da raiz, normalmente vazio

        val result = mutableMapOf<String, Int>()
        while (offset < bytes.size) {
            val tagType = bytes[offset].toInt() and 0xFF
            offset += 1
            if (tagType == 0) break // TAG_End

            val nameStart = offset
            offset = skipString(bytes, offset)
            val fieldName = String(bytes, nameStart + 2, offset - nameStart - 2, Charsets.UTF_8)

            if (tagType == 1 && fieldName in TARGET_FIELDS) {
                // TAG_Byte: o valor esta bem aqui, ocupa 1 byte
                result[fieldName] = offset
                offset += 1
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
        return ByteBuffer.wrap(bytes, offset, 4).order(ByteOrder.LITTLE_ENDIAN).int
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
