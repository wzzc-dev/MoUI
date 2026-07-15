package dev.wzzc.moui.mobile

import android.content.Context

interface MoUIMobilePlugin {
    val id: String

    fun install(context: Context) = Unit

    fun install(context: Context, capabilities: MoUIMobilePluginCapabilities) {
        install(context)
    }
}
