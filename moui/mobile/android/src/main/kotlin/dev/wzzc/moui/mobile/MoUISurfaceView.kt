package dev.wzzc.moui.mobile

import android.content.Context
import android.graphics.Matrix
import android.text.Editable
import android.text.InputType
import android.text.Selection
import android.text.SpannableStringBuilder
import android.util.Log
import android.view.KeyEvent
import android.view.SurfaceView
import android.view.View
import android.view.accessibility.AccessibilityNodeProvider
import android.view.inputmethod.BaseInputConnection
import android.view.inputmethod.CursorAnchorInfo
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.view.inputmethod.InputMethodManager
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import org.json.JSONTokener
import kotlin.math.max

internal class MoUISurfaceView(context: Context) : SurfaceView(context) {
    private val editable = SpannableStringBuilder()
    private val accessibility = MoUIAccessibilityBridge(this)
    private val clipboard = MoUIClipboardService(context)
    private val inputMethodManager = context.getSystemService(InputMethodManager::class.java)
    private var imeEnabled = false
    private var composing = false
    private var imeRevision = -1
    private var sessionGeneration: Int? = null

    init {
        isFocusable = true
        isFocusableInTouchMode = true
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        setZOrderOnTop(false)
    }

    override fun onCheckIsTextEditor(): Boolean = imeEnabled

    override fun onCreateInputConnection(outAttrs: EditorInfo): InputConnection {
        outAttrs.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
        outAttrs.imeOptions = EditorInfo.IME_ACTION_DONE or EditorInfo.IME_FLAG_NO_EXTRACT_UI
        outAttrs.initialSelStart = max(0, Selection.getSelectionStart(editable))
        outAttrs.initialSelEnd = max(0, Selection.getSelectionEnd(editable))
        return MoUIInputConnection()
    }

    override fun getAccessibilityNodeProvider(): AccessibilityNodeProvider = accessibility

    fun applyHostUpdates(
        encoded: String?,
        platformViews: MoUIPlatformViewController,
    ) {
        val source = encoded?.trim().orEmpty()
        if (source.isEmpty() || source == "[]") return
        try {
            val value = JSONTokener(source).nextValue()
            val (updates, generation) = when (value) {
                is JSONArray -> value to null
                is JSONObject -> {
                    val schemaVersion = value.optInt("schemaVersion", -1)
                    if (schemaVersion != HOST_WIRE_SCHEMA_VERSION) {
                        Log.e(LOG_TAG, "unsupported mobile host wire schema=$schemaVersion")
                        return
                    }
                    value.getJSONArray("updates") to
                        value.optInt("sessionGeneration").takeIf {
                            value.has("sessionGeneration")
                        }
                }
                else -> throw JSONException("mobile host updates must be an array or object")
            }
            if (generation != null &&
                sessionGeneration != null &&
                generation != sessionGeneration
            ) {
                clearHostState()
            }
            if (generation != null) sessionGeneration = generation
            for (index in 0 until updates.length()) {
                runCatching {
                    applyHostUpdate(updates.getJSONObject(index), generation, platformViews)
                }.onFailure { error ->
                    Log.e(LOG_TAG, "invalid mobile host update at index=$index", error)
                }
            }
        } catch (error: JSONException) {
            Log.e(LOG_TAG, "invalid mobile host update envelope", error)
        }
    }

    fun clearHostState() {
        MoUIHostServices.reset()
        imeEnabled = false
        composing = false
        imeRevision = -1
        sessionGeneration = null
        editable.clear()
        inputMethodManager?.hideSoftInputFromWindow(windowToken, 0)
        accessibility.clear()
        clearFocus()
    }

    private fun applyHostUpdate(
        update: JSONObject,
        generation: Int?,
        platformViews: MoUIPlatformViewController,
    ) {
        when (update.optString("kind")) {
            "ime" -> applyIme(update.getJSONObject("payload"))
            "semantics" -> accessibility.update(update.getJSONObject("payload"))
            "clipboard" -> clipboard.apply(update, generation)
            "diagnostic" -> Log.i(
                LOG_TAG,
                update.optString("payload", "moui-mobile diagnostic"),
            )
            "platform-views" -> platformViews.sync(update.getJSONObject("payload"), generation)
            "platform-channel" -> MoUIHostServices.dispatch(update, generation)
            else -> Log.w(LOG_TAG, "unknown mobile host update kind=${update.optString("kind")}")
        }
    }

    private fun applyIme(payload: JSONObject) {
        val revision = payload.optInt("revision", imeRevision + 1)
        if (revision <= imeRevision) return
        imeRevision = revision
        val nextEnabled = payload.optBoolean("enabled")
        val text = payload.optString("text")
        val caret = payload.optInt("caret", text.length).coerceIn(0, text.length)
        val selection = payload.optJSONObject("selection")
        val selectionStart = selection
            ?.optInt("start", caret)
            ?.coerceIn(0, text.length)
            ?: caret
        val selectionEnd = selection
            ?.optInt("end", caret)
            ?.coerceIn(0, text.length)
            ?: caret
        editable.replace(0, editable.length, text)
        Selection.setSelection(editable, selectionStart, selectionEnd)
        composing = payload.optString("composition").isNotEmpty()
        imeEnabled = nextEnabled
        Log.i(LOG_TAG, "moui-mobile service ime state enabled=$imeEnabled")
        if (nextEnabled) {
            requestFocus()
            inputMethodManager?.restartInput(this)
            inputMethodManager?.showSoftInput(this, InputMethodManager.SHOW_IMPLICIT)
            updateCursorAnchor(payload.optJSONObject("candidate_anchor"))
        } else {
            composing = false
            inputMethodManager?.hideSoftInputFromWindow(windowToken, 0)
            clearFocus()
        }
    }

    private fun updateCursorAnchor(anchor: JSONObject?) {
        val origin = anchor?.optJSONObject("origin") ?: return
        val size = anchor.optJSONObject("size") ?: return
        val density = resources.displayMetrics.density
        val x = origin.optDouble("x").toFloat() * density
        val y = origin.optDouble("y").toFloat() * density
        val height = max(1f, size.optDouble("height").toFloat() * density)
        val info = CursorAnchorInfo.Builder()
            .setMatrix(Matrix())
            .setSelectionRange(
                Selection.getSelectionStart(editable),
                Selection.getSelectionEnd(editable),
            )
            .setInsertionMarkerLocation(
                x,
                y,
                y,
                y + height,
                CursorAnchorInfo.FLAG_HAS_VISIBLE_REGION,
            )
            .build()
        inputMethodManager?.updateCursorAnchorInfo(this, info)
    }

    private inner class MoUIInputConnection : BaseInputConnection(this@MoUISurfaceView, true) {
        override fun getEditable(): Editable = editable

        override fun commitText(text: CharSequence, newCursorPosition: Int): Boolean {
            val start = max(0, Selection.getSelectionStart(editable))
            val end = max(0, Selection.getSelectionEnd(editable))
            val handled = if (composing) {
                MoUINativeBridge.dispatchTextInput(5, text.toString(), 0, 0)
            } else {
                MoUINativeBridge.dispatchTextInput(1, text.toString(), start, end)
            }
            composing = false
            Log.i(LOG_TAG, "moui-mobile service ime edit kind=commit result=${handled.asInt()}")
            return super.commitText(text, newCursorPosition) && handled
        }

        override fun setComposingText(text: CharSequence, newCursorPosition: Int): Boolean {
            if (!composing) {
                MoUINativeBridge.dispatchTextInput(3, "", 0, 0)
                composing = true
            }
            val cursor = max(0, text.length)
            val handled = MoUINativeBridge.dispatchTextInput(
                4,
                text.toString(),
                cursor,
                cursor,
            )
            return super.setComposingText(text, newCursorPosition) && handled
        }

        override fun finishComposingText(): Boolean {
            val handled = !composing || MoUINativeBridge.dispatchTextInput(5, "", 0, 0)
            composing = false
            return super.finishComposingText() && handled
        }

        override fun deleteSurroundingText(beforeLength: Int, afterLength: Int): Boolean {
            val handled = MoUINativeBridge.dispatchTextInput(
                6,
                "",
                beforeLength,
                afterLength,
            )
            return super.deleteSurroundingText(beforeLength, afterLength) && handled
        }

        override fun setSelection(start: Int, end: Int): Boolean {
            val handled = MoUINativeBridge.dispatchTextInput(2, "", start, end)
            return super.setSelection(start, end) && handled
        }

        override fun performEditorAction(actionCode: Int): Boolean =
            MoUINativeBridge.dispatchCommand(3)

        override fun performContextMenuAction(id: Int): Boolean = when (id) {
            android.R.id.copy -> MoUINativeBridge.dispatchCommand(0)
            android.R.id.cut -> MoUINativeBridge.dispatchCommand(1)
            android.R.id.paste -> MoUINativeBridge.dispatchCommand(2)
            else -> super.performContextMenuAction(id)
        }

        override fun sendKeyEvent(event: KeyEvent): Boolean {
            if (event.action == KeyEvent.ACTION_DOWN && event.keyCode == KeyEvent.KEYCODE_DEL) {
                return deleteSurroundingText(1, 0)
            }
            if (event.action == KeyEvent.ACTION_DOWN && event.keyCode == KeyEvent.KEYCODE_ENTER) {
                return performEditorAction(EditorInfo.IME_ACTION_DONE)
            }
            return super.sendKeyEvent(event)
        }
    }

    companion object {
        private const val LOG_TAG = "MoUIMobile"
        private const val HOST_WIRE_SCHEMA_VERSION = 1

        private fun Boolean.asInt(): Int = if (this) 1 else 0
    }
}
