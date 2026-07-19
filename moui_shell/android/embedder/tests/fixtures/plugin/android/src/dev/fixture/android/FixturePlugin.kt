package dev.fixture.android

import android.content.Context
import dev.wzzc.moui.shell.MoUIShellPlugin

class FixturePlugin : MoUIShellPlugin {
    override val id: String = "dev.fixture.android-plugin"

    override fun install(context: Context) {
        check(context === context.applicationContext)
        check(FixturePluginHelper.value() == "android-plugin")
    }
}
