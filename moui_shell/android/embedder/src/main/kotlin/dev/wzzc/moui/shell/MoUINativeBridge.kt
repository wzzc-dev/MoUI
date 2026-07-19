package dev.wzzc.moui.shell

import android.view.Surface

internal class MoUINativeBridge private constructor() {
    companion object {
        @JvmStatic external fun attachSurface(surface: Surface, width: Int, height: Int, density: Double): Boolean
        @JvmStatic external fun resize(width: Int, height: Int, density: Double): Boolean
        @JvmStatic external fun dispatchPointer(phase: Int, x: Double, y: Double, timeMs: Double): Boolean
        @JvmStatic external fun dispatchScroll(
            x: Double,
            y: Double,
            deltaX: Double,
            deltaY: Double,
            phase: Int,
        ): Boolean
        @JvmStatic external fun frameTick(timeMs: Double): Boolean
        @JvmStatic external fun takeHostUpdates(): String
        @JvmStatic external fun dispatchHostResponseEnvelope(envelopeJson: String): Boolean
        @JvmStatic external fun dispatchTextInput(kind: Int, text: String, start: Int, end: Int): Boolean
        @JvmStatic external fun dispatchCommand(kind: Int): Boolean
        @JvmStatic external fun dispatchAccessibility(elementId: Int, action: Int, value: String): Boolean
        @JvmStatic external fun completeClipboard(
            sessionGeneration: Int,
            id: Int,
            kind: Int,
            text: String,
            bytes: ByteArray,
        ): Boolean
        @JvmStatic external fun renderFrame(): Boolean
        @JvmStatic external fun detachSurface()
        // Process-terminal hook. Activity recreation only detaches its surface.
        @JvmStatic external fun destroyApplication(): Boolean
        @JvmStatic external fun rendererConfigure(mode: String): Boolean
        @JvmStatic external fun rendererStatusJson(): String
    }
}
