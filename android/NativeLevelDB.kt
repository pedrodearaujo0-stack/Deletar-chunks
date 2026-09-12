package com.example.chunktool

class NativeLevelDB {
    companion object {
        init {
            System.loadLibrary("chunktool_leveldb")
        }
    }

    external fun nativeOpen(path: String): Long
    external fun nativeLastError(): String
    external fun nativeClose(dbHandle: Long)
    external fun nativeCreateIterator(dbHandle: Long): Long
    external fun nativeIteratorSeekToFirst(iterHandle: Long)
    external fun nativeIteratorValid(iterHandle: Long): Boolean
    external fun nativeIteratorNext(iterHandle: Long)
    external fun nativeIteratorKey(iterHandle: Long): ByteArray
    external fun nativeIteratorSeek(iterHandle: Long, target: ByteArray)
    external fun nativeDelete(dbHandle: Long, key: ByteArray): Boolean
    external fun nativeIteratorClose(iterHandle: Long)
}
