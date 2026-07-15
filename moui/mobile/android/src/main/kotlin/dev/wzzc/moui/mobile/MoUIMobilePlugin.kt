package dev.wzzc.moui.mobile

import android.content.Context

interface MoUIMobilePlugin {
    val id: String

    fun install(context: Context)
}
