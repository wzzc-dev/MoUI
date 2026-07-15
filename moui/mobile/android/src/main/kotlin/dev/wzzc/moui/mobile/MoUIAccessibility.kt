@file:Suppress("DEPRECATION")

package dev.wzzc.moui.mobile

import android.graphics.Rect
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityNodeProvider
import org.json.JSONArray
import org.json.JSONObject

internal class MoUIAccessibilityBridge(
    private val host: View,
) : AccessibilityNodeProvider() {
    private val nodes = linkedMapOf<Int, MoUISemanticsNode>()
    private var accessibilityFocus = View.NO_ID
    private var revision = -1

    fun update(payload: JSONObject) {
        val nextRevision = payload.optInt("revision", revision + 1)
        if (nextRevision <= revision) return
        revision = nextRevision
        nodes.clear()
        val encoded = payload.getJSONArray("nodes")
        for (index in 0 until encoded.length()) {
            val node = MoUISemanticsNode.fromJson(encoded.getJSONObject(index))
            nodes[node.id] = node
        }
        if (!nodes.containsKey(accessibilityFocus)) accessibilityFocus = View.NO_ID
        host.sendAccessibilityEvent(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED)
        Log.i(LOG_TAG, "moui-mobile service accessibility tree nodes=${nodes.size}")
    }

    fun clear() {
        nodes.clear()
        accessibilityFocus = View.NO_ID
        revision = -1
        host.sendAccessibilityEvent(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED)
    }

    override fun createAccessibilityNodeInfo(virtualViewId: Int): AccessibilityNodeInfo? {
        if (virtualViewId == View.NO_ID) {
            val root = AccessibilityNodeInfo.obtain(host)
            root.className = host.javaClass.name
            nodes.values.filter { it.parentId == null }.forEach { root.addChild(host, it.id) }
            return root
        }
        val node = nodes[virtualViewId] ?: return null
        return AccessibilityNodeInfo.obtain().apply {
            packageName = host.context.packageName
            className = node.androidClassName()
            setSource(host, node.id)
            if (node.parentId == null) setParent(host) else setParent(host, node.parentId)
            nodes.values.filter { it.parentId == node.id }.forEach { addChild(host, it.id) }
            text = node.label.ifEmpty { node.value }
            contentDescription = node.description.ifEmpty { node.label }
            isEnabled = !node.disabled
            isSelected = node.selected
            isCheckable = node.checkable
            isChecked = node.checked
            isFocusable = node.focusable
            isFocused = node.focused
            isAccessibilityFocused = accessibilityFocus == node.id
            setBoundsInParent(node.bounds(density()))
            val location = IntArray(2)
            host.getLocationOnScreen(location)
            val screen = node.bounds(density()).apply { offset(location[0], location[1]) }
            setBoundsInScreen(screen)
            node.addActions(this)
        }
    }

    override fun performAction(virtualViewId: Int, action: Int, arguments: Bundle?): Boolean {
        val node = nodes[virtualViewId] ?: return false
        return when (action) {
            AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS -> {
                accessibilityFocus = virtualViewId
                sendVirtualEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED)
                Log.i(LOG_TAG, "moui-mobile service accessibility focus id=$virtualViewId")
                MoUINativeBridge.dispatchAccessibility(virtualViewId, 1, "")
            }
            AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS -> {
                accessibilityFocus = View.NO_ID
                sendVirtualEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUS_CLEARED)
                true
            }
            AccessibilityNodeInfo.ACTION_FOCUS ->
                MoUINativeBridge.dispatchAccessibility(virtualViewId, 1, "")
            AccessibilityNodeInfo.ACTION_CLICK -> {
                Log.i(LOG_TAG, "moui-mobile service accessibility action=activate id=$virtualViewId")
                MoUINativeBridge.dispatchAccessibility(virtualViewId, 0, "")
            }
            AccessibilityNodeInfo.ACTION_SET_TEXT -> {
                val value = arguments
                    ?.getCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE)
                    ?.toString()
                    .orEmpty()
                MoUINativeBridge.dispatchAccessibility(virtualViewId, 2, value)
            }
            AccessibilityNodeInfo.ACTION_SCROLL_FORWARD ->
                MoUINativeBridge.dispatchAccessibility(virtualViewId, 4, "forward")
            AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD ->
                MoUINativeBridge.dispatchAccessibility(virtualViewId, 4, "backward")
            else -> false
        }
    }

    private fun sendVirtualEvent(id: Int, type: Int) {
        val event = AccessibilityEvent.obtain(type).apply {
            packageName = host.context.packageName
            setSource(host, id)
        }
        host.parent?.requestSendAccessibilityEvent(host, event)
    }

    private fun density(): Float = host.resources.displayMetrics.density

    companion object {
        private const val LOG_TAG = "MoUIMobile"
    }
}

private data class MoUISemanticsNode(
    val id: Int,
    val parentId: Int?,
    val role: String,
    val label: String,
    val value: String,
    val description: String,
    val disabled: Boolean,
    val selected: Boolean,
    val checked: Boolean,
    val focused: Boolean,
    val focusable: Boolean,
    val checkable: Boolean,
    val x: Double,
    val y: Double,
    val width: Double,
    val height: Double,
    val actions: JSONArray,
) {
    fun bounds(density: Float): Rect = Rect(
        (x * density).toInt(),
        (y * density).toInt(),
        ((x + width) * density).toInt(),
        ((y + height) * density).toInt(),
    )

    fun androidClassName(): String = when (role) {
        "Button" -> "android.widget.Button"
        "TextField" -> "android.widget.EditText"
        "Checkbox" -> "android.widget.CheckBox"
        "Switch" -> "android.widget.Switch"
        "ScrollView" -> "android.widget.ScrollView"
        "List" -> "android.widget.ListView"
        else -> "android.view.View"
    }

    fun addActions(info: AccessibilityNodeInfo) {
        if (hasAction("Activate") || hasAction("Select")) {
            info.addAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        if (hasAction("Focus")) info.addAction(AccessibilityNodeInfo.ACTION_FOCUS)
        if (hasAction("SetText")) info.addAction(AccessibilityNodeInfo.ACTION_SET_TEXT)
        if (hasAction("Scroll")) {
            info.addAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)
            info.addAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD)
        }
    }

    private fun hasAction(action: String): Boolean =
        (0 until actions.length()).any { actions.optString(it) == action }

    companion object {
        fun fromJson(value: JSONObject): MoUISemanticsNode {
            val state = value.getJSONObject("state")
            val frame = value.getJSONObject("frame")
            val origin = frame.getJSONObject("origin")
            val size = frame.getJSONObject("size")
            val actions = value.getJSONArray("actions")
            val role = value.optString("role", "None")
            return MoUISemanticsNode(
                id = value.getInt("element_id"),
                parentId = if (value.isNull("parent_id")) null else value.getInt("parent_id"),
                role = role,
                label = value.optString("label"),
                value = value.optString("value"),
                description = value.optString("description"),
                disabled = state.optBoolean("disabled"),
                selected = state.optBoolean("selected"),
                checked = state.optBoolean("checked"),
                focused = state.optBoolean("focused"),
                focusable = (0 until actions.length()).any { actions.optString(it) == "Focus" },
                checkable = role == "Checkbox" || role == "Switch" || role == "Radio",
                x = origin.getDouble("x"),
                y = origin.getDouble("y"),
                width = size.getDouble("width"),
                height = size.getDouble("height"),
                actions = actions,
            )
        }
    }
}
