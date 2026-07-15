package dev.fixture.android

import android.content.Context
import dev.wzzc.moui.mobile.MoUIMobilePlugin

class FixturePlugin : MoUIMobilePlugin {
    override val id: String = "dev.fixture.android-plugin"

    override fun install(context: Context) {
        check(context === context.applicationContext)
        check(FixturePluginHelper.value() == "android-plugin")
    }
}
