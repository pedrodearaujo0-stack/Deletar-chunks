#include <jni.h>
#include <string>
#include "leveldb/db.h"
#include "leveldb/options.h"
#include "leveldb/iterator.h"
#include "leveldb/zlib_compressor.h"
#include "subchunk_decoder.h"

static std::string g_lastError;

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeOpen(JNIEnv *env, jobject, jstring pathJ) {
    const char *pathC = env->GetStringUTFChars(pathJ, nullptr);
    std::string path(pathC);
    env->ReleaseStringUTFChars(pathJ, pathC);

    leveldb::Options options;
    options.create_if_missing = false;

    static leveldb::ZlibCompressor zlibCompressor;
    static leveldb::ZlibCompressorRaw zlibCompressorRaw;
    options.compressors[0] = &zlibCompressorRaw;
    options.compressors[1] = &zlibCompressor;

    leveldb::DB *db = nullptr;
    leveldb::Status status = leveldb::DB::Open(options, path, &db);
    if (!status.ok()) {
        g_lastError = status.ToString();
        return 0;
    }
    g_lastError.clear();
    return reinterpret_cast<jlong>(db);
}

JNIEXPORT jstring JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeLastError(JNIEnv *env, jobject) {
    return env->NewStringUTF(g_lastError.c_str());
}

JNIEXPORT void JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeClose(JNIEnv *, jobject, jlong dbHandle) {
    auto *db = reinterpret_cast<leveldb::DB *>(dbHandle);
    delete db;
}

JNIEXPORT jlong JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeCreateIterator(JNIEnv *, jobject, jlong dbHandle) {
    auto *db = reinterpret_cast<leveldb::DB *>(dbHandle);
    leveldb::Iterator *it = db->NewIterator(leveldb::ReadOptions());
    return reinterpret_cast<jlong>(it);
}

JNIEXPORT void JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeIteratorSeekToFirst(JNIEnv *, jobject, jlong iterHandle) {
    auto *it = reinterpret_cast<leveldb::Iterator *>(iterHandle);
    it->SeekToFirst();
}

JNIEXPORT jboolean JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeIteratorValid(JNIEnv *, jobject, jlong iterHandle) {
    auto *it = reinterpret_cast<leveldb::Iterator *>(iterHandle);
    return it->Valid() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeIteratorNext(JNIEnv *, jobject, jlong iterHandle) {
    auto *it = reinterpret_cast<leveldb::Iterator *>(iterHandle);
    it->Next();
}

JNIEXPORT jbyteArray JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeIteratorKey(JNIEnv *env, jobject, jlong iterHandle) {
    auto *it = reinterpret_cast<leveldb::Iterator *>(iterHandle);
    leveldb::Slice key = it->key();
    jbyteArray result = env->NewByteArray(static_cast<jsize>(key.size()));
    env->SetByteArrayRegion(result, 0, static_cast<jsize>(key.size()),
                             reinterpret_cast<const jbyte *>(key.data()));
    return result;
}

JNIEXPORT void JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeIteratorSeek(JNIEnv *env, jobject, jlong iterHandle, jbyteArray targetJ) {
    auto *it = reinterpret_cast<leveldb::Iterator *>(iterHandle);
    jsize len = env->GetArrayLength(targetJ);
    jbyte *bytes = env->GetByteArrayElements(targetJ, nullptr);
    leveldb::Slice target(reinterpret_cast<const char *>(bytes), static_cast<size_t>(len));
    it->Seek(target);
    env->ReleaseByteArrayElements(targetJ, bytes, JNI_ABORT);
}

JNIEXPORT jboolean JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeDelete(JNIEnv *env, jobject, jlong dbHandle, jbyteArray keyJ) {
    auto *db = reinterpret_cast<leveldb::DB *>(dbHandle);
    jsize len = env->GetArrayLength(keyJ);
    jbyte *bytes = env->GetByteArrayElements(keyJ, nullptr);
    leveldb::Slice key(reinterpret_cast<const char *>(bytes), static_cast<size_t>(len));
    leveldb::Status status = db->Delete(leveldb::WriteOptions(), key);
    env->ReleaseByteArrayElements(keyJ, bytes, JNI_ABORT);
    return status.ok() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeIteratorClose(JNIEnv *, jobject, jlong iterHandle) {
    auto *it = reinterpret_cast<leveldb::Iterator *>(iterHandle);
    delete it;
}

static void AppendPrefix(std::string &key, int32_t x, int32_t z, int32_t dimension) {
    key.append(reinterpret_cast<const char *>(&x), 4);
    key.append(reinterpret_cast<const char *>(&z), 4);
    if (dimension != 0) {
        key.append(reinterpret_cast<const char *>(&dimension), 4);
    }
}

JNIEXPORT jstring JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeGetTopBlocks(
    JNIEnv *env, jobject, jlong dbHandle, jint x, jint z, jint dimension) {
    auto *db = reinterpret_cast<leveldb::DB *>(dbHandle);

    std::string topBlocks[256];  // indice = lx * 16 + lz
    int filled = 0;

    // Sobe de -4 (chao) ate 19 (teto), mas testamos de cima pra baixo.
    for (int subY = 19; subY >= -4 && filled < 256; subY--) {
        std::string key;
        AppendPrefix(key, x, z, dimension);
        key.push_back(static_cast<char>(0x2f));  // tag SubChunkPrefix
        key.push_back(static_cast<char>(subY));

        std::string value;
        leveldb::Status status = db->Get(leveldb::ReadOptions(), key, &value);
        if (!status.ok()) continue;

        SubchunkDecodeResult decoded = DecodeSubchunk(
            reinterpret_cast<const uint8_t *>(value.data()), value.size());
        if (!decoded.success) continue;

        for (int lx = 0; lx < 16 && filled < 256; lx++) {
            for (int lz = 0; lz < 16; lz++) {
                int colIndex = lx * 16 + lz;
                if (!topBlocks[colIndex].empty()) continue;
                for (int ly = 15; ly >= 0; ly--) {
                    int blockIndex = (lx * 16 + lz) * 16 + ly;
                    const std::string &name = decoded.blockNames[blockIndex];
                    if (!name.empty() && name != "minecraft:air") {
                        topBlocks[colIndex] = name;
                        filled++;
                        break;
                    }
                }
            }
        }
    }

    std::string joined;
    for (int i = 0; i < 256; i++) {
        joined += topBlocks[i];
        if (i < 255) joined += ';';
    }

    return env->NewStringUTF(joined.c_str());
}

// Versao leve: le so 1 coluna central do chunk (bem mais rapido que as 256),
// usada pra colorir o mapa sem travar em mundos com muitos chunks.
JNIEXPORT jstring JNICALL
Java_com_example_chunktool_NativeLevelDB_nativeGetChunkTopBlock(
    JNIEnv *env, jobject, jlong dbHandle, jint x, jint z, jint dimension) {
    auto *db = reinterpret_cast<leveldb::DB *>(dbHandle);

    const int lx = 8, lz = 8;  // coluna central do chunk

    for (int subY = 19; subY >= -4; subY--) {
        std::string key;
        AppendPrefix(key, x, z, dimension);
        key.push_back(static_cast<char>(0x2f));
        key.push_back(static_cast<char>(subY));

        std::string value;
        leveldb::Status status = db->Get(leveldb::ReadOptions(), key, &value);
        if (!status.ok()) continue;

        SubchunkDecodeResult decoded = DecodeSubchunk(
            reinterpret_cast<const uint8_t *>(value.data()), value.size());
        if (!decoded.success) continue;

        for (int ly = 15; ly >= 0; ly--) {
            int blockIndex = (lx * 16 + lz) * 16 + ly;
            const std::string &name = decoded.blockNames[blockIndex];
            if (!name.empty() && name != "minecraft:air") {
                return env->NewStringUTF(name.c_str());
            }
        }
    }

    return env->NewStringUTF("");
}

}
