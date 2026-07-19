package dev.wzzc.moui.shell

import android.content.Context

interface MoUIShellPlugin {
    val id: String

    fun install(context: Context) = Unit

    fun install(context: Context, capabilities: MoUIShellPluginCapabilities) {
        install(context)
    }
}
