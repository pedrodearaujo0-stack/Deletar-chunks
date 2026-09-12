#pragma once

#include <cstdint>
#include <cstring>
#include <string>

namespace nbt {

inline uint16_t ReadU16(const uint8_t *data, size_t &offset) {
    uint16_t v;
    memcpy(&v, data + offset, 2);
    offset += 2;
    return v;
}

inline int32_t ReadI32(const uint8_t *data, size_t &offset) {
    int32_t v;
    memcpy(&v, data + offset, 4);
    offset += 4;
    return v;
}

inline std::string ReadString(const uint8_t *data, size_t &offset, size_t size) {
    uint16_t len = ReadU16(data, offset);
    if (offset + len > size) {
        offset = size;
        return "";
    }
    std::string s(reinterpret_cast<const char *>(data + offset), len);
    offset += len;
    return s;
}

void SkipTag(uint8_t tagType, const uint8_t *data, size_t &offset, size_t size);

// Percorre o corpo de um compound (ate achar TAG_End), guardando em outName
// o valor do campo string de nome "name", se existir nesse nivel.
inline void SkipCompoundBody(const uint8_t *data, size_t &offset, size_t size, std::string *outName) {
    while (offset < size) {
        uint8_t tagType = data[offset];
        offset += 1;
        if (tagType == 0) return;  // TAG_End
        std::string fieldName = ReadString(data, offset, size);
        if (tagType == 8 && fieldName == "name" && outName != nullptr) {
            *outName = ReadString(data, offset, size);
        } else {
            SkipTag(tagType, data, offset, size);
        }
    }
}

inline void SkipTag(uint8_t tagType, const uint8_t *data, size_t &offset, size_t size) {
    switch (tagType) {
        case 1: offset += 1; break;   // Byte
        case 2: offset += 2; break;   // Short
        case 3: offset += 4; break;   // Int
        case 4: offset += 8; break;   // Long
        case 5: offset += 4; break;   // Float
        case 6: offset += 8; break;   // Double
        case 7: {                     // Byte Array
            int32_t len = ReadI32(data, offset);
            offset += (len > 0 ? len : 0);
            break;
        }
        case 8: {                     // String
            ReadString(data, offset, size);
            break;
        }
        case 9: {                     // List
            uint8_t itemType = data[offset]; offset += 1;
            int32_t count = ReadI32(data, offset);
            for (int32_t i = 0; i < count && offset < size; i++) {
                SkipTag(itemType, data, offset, size);
            }
            break;
        }
        case 10: {                    // Compound
            SkipCompoundBody(data, offset, size, nullptr);
            break;
        }
        case 11: {                    // Int Array
            int32_t len = ReadI32(data, offset);
            offset += (len > 0 ? len * 4 : 0);
            break;
        }
        case 12: {                    // Long Array
            int32_t len = ReadI32(data, offset);
            offset += (len > 0 ? len * 8 : 0);
            break;
        }
        default:
            offset = size;  // tipo desconhecido, nao da pra continuar com seguranca
            break;
    }
}

// Le uma entrada de paleta (um compound completo), retorna o campo "name".
inline std::string ReadPaletteEntryName(const uint8_t *data, size_t &offset, size_t size) {
    if (offset >= size) return "";
    uint8_t tagType = data[offset]; offset += 1;
    if (tagType != 10) return "";
    ReadString(data, offset, size);  // nome da raiz, geralmente vazio
    std::string blockName;
    SkipCompoundBody(data, offset, size, &blockName);
    return blockName;
}

}  // namespace nbt
