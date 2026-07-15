package dev.wzzc.moui.mobile

import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException

class MoUIClipboardProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String = mimeType

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        val providerContext = context ?: throw FileNotFoundException("clipboard provider unavailable")
        if (mode != "r") throw FileNotFoundException("clipboard image is read-only")
        return ParcelFileDescriptor.open(
            File(providerContext.cacheDir, FILE_NAME),
            ParcelFileDescriptor.MODE_READ_ONLY,
        )
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    companion object {
        private const val FILE_NAME = "moui-mobile-clipboard-image"

        @Volatile
        private var mimeType = "image/png"

        internal fun publish(context: Context, mime: String, bytes: ByteArray): Uri {
            File(context.cacheDir, FILE_NAME).outputStream().use { it.write(bytes) }
            mimeType = mime.ifBlank { "image/png" }
            return Uri.parse("content://${context.packageName}.moui.clipboard/image")
        }
    }
}

internal class MoUIClipboardService(private val context: Context) {
    private val manager = context.getSystemService(ClipboardManager::class.java)

    fun apply(update: JSONObject, sessionGeneration: Int?) {
        val id = update.optInt("id")
        if (sessionGeneration == null) {
            Log.e(LOG_TAG, "clipboard update is missing Host Wire session generation id=$id")
            return
        }
        val payload = update.optJSONObject("payload")
        if (payload == null) {
            completeError(sessionGeneration, id, "invalid clipboard payload")
            return
        }
        val operation = payload.optString("operation")
        try {
            val accepted = when (operation) {
                "read-text" -> {
                    val clip = manager?.primaryClip
                    val text = if (clip != null && clip.itemCount > 0) {
                        clip.getItemAt(0).coerceToText(context)?.toString().orEmpty()
                    } else {
                        ""
                    }
                    MoUINativeBridge.completeClipboard(
                        sessionGeneration,
                        id,
                        1,
                        text,
                        byteArrayOf(),
                    )
                }
                "write-text" -> {
                    manager?.setPrimaryClip(ClipData.newPlainText("MoUI", payload.optString("text")))
                        ?: error("clipboard service is unavailable")
                    MoUINativeBridge.completeClipboard(
                        sessionGeneration,
                        id,
                        3,
                        "",
                        byteArrayOf(),
                    )
                }
                "read-image" -> {
                    val bytes = readImage()
                    if (bytes == null) {
                        completeError(sessionGeneration, id, "clipboard image is unavailable")
                    } else {
                        MoUINativeBridge.completeClipboard(
                            sessionGeneration,
                            id,
                            2,
                            "",
                            bytes,
                        )
                    }
                }
                "write-image" -> {
                    val bytes = payload.optJSONArray("bytes").toByteArray()
                    val uri = MoUIClipboardProvider.publish(
                        context,
                        payload.optString("mime", "image/png"),
                        bytes,
                    )
                    manager?.setPrimaryClip(
                        ClipData.newUri(context.contentResolver, "MoUI image", uri),
                    ) ?: error("clipboard service is unavailable")
                    MoUINativeBridge.completeClipboard(
                        sessionGeneration,
                        id,
                        3,
                        "",
                        byteArrayOf(),
                    )
                }
                else -> completeError(
                    sessionGeneration,
                    id,
                    "unsupported clipboard operation: $operation",
                )
            }
            Log.i(
                LOG_TAG,
                "moui-mobile service clipboard complete operation=$operation " +
                    "accepted=${if (accepted) 1 else 0}",
            )
        } catch (error: Exception) {
            completeError(
                sessionGeneration,
                id,
                error.message ?: error.javaClass.simpleName,
            )
        }
    }

    private fun readImage(): ByteArray? {
        val clip = manager?.primaryClip ?: return null
        if (clip.itemCount == 0) return null
        val uri = clip.getItemAt(0).uri ?: return null
        return context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
    }

    private fun completeError(sessionGeneration: Int, id: Int, message: String): Boolean =
        MoUINativeBridge.completeClipboard(
            sessionGeneration,
            id,
            0,
            message,
            byteArrayOf(),
        )

    private fun JSONArray?.toByteArray(): ByteArray {
        if (this == null) return byteArrayOf()
        return ByteArray(length()) { index -> optInt(index).toByte() }
    }

    companion object {
        private const val LOG_TAG = "MoUIMobile"
    }
}
