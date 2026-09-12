#pragma once

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "nbt_reader.h"

struct SubchunkDecodeResult {
    bool success = false;
    std::string error;
    // 4096 posicoes, indice = (x * 16 + z) * 16 + y. "" significa ar/vazio.
    std::vector<std::string> blockNames;
};

inline SubchunkDecodeResult DecodeSubchunk(const uint8_t *data, size_t size) {
    SubchunkDecodeResult result;
    if (size < 2) {
        result.error = "dados pequenos demais";
        return result;
    }

    size_t offset = 0;
    uint8_t version = data[offset]; offset += 1;

    if (version != 8 && version != 9) {
        result.error = "versao de subchunk nao suportada: " + std::to_string((int)version);
        return result;
    }

    uint8_t layerCount = data[offset]; offset += 1;

    if (version == 9) {
        // versao 9 tem um byte extra: o indice Y do subchunk (redundante com a chave)
        offset += 1;
    }

    if (layerCount == 0) {
        result.error = "zero camadas de blocos";
        return result;
    }

    result.blockNames.assign(4096, "");

    for (uint8_t layer = 0; layer < layerCount; layer++) {
        if (offset >= size) {
            result.error = "acabaram os dados antes do esperado (camada)";
            return result;
        }
        uint8_t paletteAndFlag = data[offset]; offset += 1;
        uint8_t bitsPerBlock = paletteAndFlag >> 1;

        std::vector<uint32_t> indices(4096, 0);

        if (bitsPerBlock > 0) {
            uint32_t blocksPerWord = 32 / bitsPerBlock;
            uint32_t wordCount = (4096 + blocksPerWord - 1) / blocksPerWord;

            std::vector<uint32_t> words(wordCount);
            for (uint32_t w = 0; w < wordCount; w++) {
                if (offset + 4 > size) {
                    result.error = "dados de indice incompletos";
                    return result;
                }
                uint32_t word;
                memcpy(&word, data + offset, 4);
                offset += 4;
                words[w] = word;
            }

            uint32_t mask = (bitsPerBlock >= 32) ? 0xFFFFFFFFu : ((1u << bitsPerBlock) - 1u);
            for (uint32_t i = 0; i < 4096; i++) {
                uint32_t wordIndex = i / blocksPerWord;
                uint32_t bitOffset = (i % blocksPerWord) * bitsPerBlock;
                indices[i] = (words[wordIndex] >> bitOffset) & mask;
            }
        }
        // se bitsPerBlock == 0, todo mundo aponta pro indice 0 (paleta de 1 bloco so)

        if (offset + 4 > size) {
            result.error = "faltou o tamanho da paleta";
            return result;
        }
        int32_t paletteSize;
        memcpy(&paletteSize, data + offset, 4);
        offset += 4;

        if (paletteSize < 0 || paletteSize > 4096) {
            result.error = "tamanho de paleta invalido: " + std::to_string(paletteSize);
            return result;
        }

        std::vector<std::string> palette(static_cast<size_t>(paletteSize));
        for (int32_t p = 0; p < paletteSize; p++) {
            palette[p] = nbt::ReadPaletteEntryName(data, offset, size);
        }

        if (layer == 0) {
            for (uint32_t i = 0; i < 4096; i++) {
                uint32_t idx = indices[i];
                if (idx < palette.size()) {
                    result.blockNames[i] = palette[idx];
                }
            }
        }
    }

    result.success = true;
    return result;
}
