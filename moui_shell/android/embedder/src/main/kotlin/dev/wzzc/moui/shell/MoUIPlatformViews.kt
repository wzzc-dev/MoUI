package dev.wzzc.moui.shell

import android.content.Context
import android.graphics.Rect
import android.graphics.RectF
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.roundToInt

data class MoUIPlatformViewPlacement(
    val id: String,
    val kind: String,
    val frame: RectF,
    val clip: RectF?,
    val properties: Map<String, String>,
)

fun interface MoUIPlatformViewEventSink {
    fun dispatch(name: String, value: String, detail: String, flag: Boolean): Boolean
}

interface MoUIPlatformViewFactory {
    fun create(context: Context, id: String, sink: MoUIPlatformViewEventSink): View
    fun update(view: View, placement: MoUIPlatformViewPlacement) = Unit
    fun dispose(view: View) = Unit
}

object MoUIPlatformViews {
    private val factories = ConcurrentHashMap<String, MoUIPlatformViewFactory>()

    @JvmStatic
    fun register(kind: String, factory: MoUIPlatformViewFactory) {
        require(kind.isNotBlank()) { "platform view kind must not be blank" }
        require(!kind.startsWith("moui.")) { "moui.* platform view kinds are reserved" }
        require(factories.putIfAbsent(kind, factory) == null) {
            "platform view kind is already registered: $kind"
        }
    }

    @JvmStatic
    fun unregister(kind: String) {
        factories.remove(kind)
    }

    internal fun factory(kind: String): MoUIPlatformViewFactory? = factories[kind]
}

internal class MoUIPlatformViewController(
    private val overlay: FrameLayout,
) {
    private data class PlatformViewKey(val kind: String, val id: String)

    private data class HostedView(
        val factory: MoUIPlatformViewFactory,
        val view: View,
        val token: Any,
    )

    private val hosted = LinkedHashMap<PlatformViewKey, HostedView>()
    private val unavailableKinds = mutableSetOf<String>()
    private var sessionGeneration: Int? = null
    private var revision = -1

    fun sync(payload: JSONObject, generation: Int?) {
        if (generation != null && generation != sessionGeneration) {
            clear()
            sessionGeneration = generation
        }
        val nextRevision = payload.optInt("revision", revision + 1)
        if (nextRevision <= revision) return
        revision = nextRevision
        val placements = buildList {
            val values = payload.optJSONArray("placements") ?: return@buildList
            for (index in 0 until values.length()) {
                runCatching { parsePlacement(values.getJSONObject(index)) }
                    .onSuccess(::add)
                    .onFailure { Log.e(LOG_TAG, "invalid platform view placement", it) }
            }
        }
        val activeKeys = placements.mapTo(mutableSetOf()) { PlatformViewKey(it.kind, it.id) }
        hosted.keys.filterNot(activeKeys::contains).forEach(::remove)
        for (placement in placements) syncPlacement(placement)
        for (placement in placements) {
            hosted[PlatformViewKey(placement.kind, placement.id)]?.view?.bringToFront()
        }
    }

    fun clear() {
        hosted.keys.toList().forEach(::remove)
        unavailableKinds.clear()
        revision = -1
        sessionGeneration = null
    }

    private fun syncPlacement(placement: MoUIPlatformViewPlacement) {
        val key = PlatformViewKey(placement.kind, placement.id)
        var current = hosted[key]
        if (current == null) {
            val factory = MoUIPlatformViews.factory(placement.kind)
            if (factory == null) {
                if (unavailableKinds.add(placement.kind)) {
                    Log.w(LOG_TAG, "platform view factory unavailable kind=${placement.kind}")
                }
                return
            }
            val token = Any()
            val sink = MoUIPlatformViewEventSink { name, value, detail, flag ->
                dispatchEvent(key, token, name, value, detail, flag)
            }
            val view = factory.create(overlay.context, placement.id, sink)
            overlay.addView(view)
            current = HostedView(factory, view, token)
            hosted[key] = current
        }
        applyLayout(current.view, placement)
        current.factory.update(current.view, placement)
    }

    private fun dispatchEvent(
        key: PlatformViewKey,
        token: Any,
        name: String,
        value: String,
        detail: String,
        flag: Boolean,
    ): Boolean {
        if (Looper.myLooper() != Looper.getMainLooper() || name.isBlank()) return false
        val active = hosted[key] ?: return false
        if (active.token !== token) return false
        val generation = sessionGeneration ?: return false
        if (generation <= 0 || revision <= 0) return false
        return runCatching {
            val event = JSONObject()
                .put("name", name)
                .put("value", value)
                .put("detail", detail)
                .put("flag", flag)
            val response = JSONObject()
                .put("kind", "platform-view")
                .put("revision", revision)
                .put("viewKind", key.kind)
                .put("id", key.id)
                .put("event", event)
            val envelope = JSONObject()
                .put("schemaVersion", HOST_WIRE_SCHEMA_VERSION)
                .put("sessionGeneration", generation)
                .put("response", response)
            MoUINativeBridge.dispatchHostResponseEnvelope(envelope.toString())
        }.getOrElse { error ->
            Log.e(LOG_TAG, "failed to dispatch platform view event kind=${key.kind} id=${key.id}", error)
            false
        }
    }

    private fun applyLayout(view: View, placement: MoUIPlatformViewPlacement) {
        val density = overlay.resources.displayMetrics.density
        val width = (placement.frame.width() * density).roundToInt().coerceAtLeast(0)
        val height = (placement.frame.height() * density).roundToInt().coerceAtLeast(0)
        val params = (view.layoutParams as? FrameLayout.LayoutParams)
            ?: FrameLayout.LayoutParams(width, height)
        params.width = width
        params.height = height
        params.leftMargin = (placement.frame.left * density).roundToInt()
        params.topMargin = (placement.frame.top * density).roundToInt()
        view.layoutParams = params
        view.visibility = if (width > 0 && height > 0) View.VISIBLE else View.GONE
        view.clipBounds = placement.clip?.let { clip ->
            val left = ((clip.left - placement.frame.left) * density).roundToInt().coerceIn(0, width)
            val top = ((clip.top - placement.frame.top) * density).roundToInt().coerceIn(0, height)
            val right = ((clip.right - placement.frame.left) * density).roundToInt().coerceIn(left, width)
            val bottom = ((clip.bottom - placement.frame.top) * density).roundToInt().coerceIn(top, height)
            Rect(left, top, right, bottom)
        }
    }

    private fun remove(key: PlatformViewKey) {
        val entry = hosted.remove(key) ?: return
        overlay.removeView(entry.view)
        entry.factory.dispose(entry.view)
    }

    private fun parsePlacement(value: JSONObject): MoUIPlatformViewPlacement {
        val properties = linkedMapOf<String, String>()
        val encodedProperties = value.optJSONArray("properties")
        if (encodedProperties != null) {
            for (index in 0 until encodedProperties.length()) {
                val property = encodedProperties.getJSONObject(index)
                properties[property.getString("key")] = property.optString("value")
            }
        }
        return MoUIPlatformViewPlacement(
            id = value.getString("id"),
            kind = value.getString("kind"),
            frame = parseRect(value.getJSONObject("frame")),
            clip = value.optJSONObject("clip")?.let(::parseRect),
            properties = properties,
        )
    }

    private fun parseRect(value: JSONObject): RectF {
        val origin = value.getJSONObject("origin")
        val size = value.getJSONObject("size")
        val left = origin.getDouble("x").toFloat()
        val top = origin.getDouble("y").toFloat()
        return RectF(
            left,
            top,
            left + size.getDouble("width").toFloat(),
            top + size.getDouble("height").toFloat(),
        )
    }

    companion object {
        private const val LOG_TAG = "MoUIShell"
        private const val HOST_WIRE_SCHEMA_VERSION = 1
    }
}
