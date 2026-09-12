#include <jni.h>
#include <string>
#include "leveldb/db.h"
#include "leveldb/options.h"
#include "leveldb/iterator.h"
#include "leveldb/zlib_compressor.h"

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

}
