package dev.wzzc.moui.shell

import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import android.view.Choreographer
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

class MoUIActivity : ComponentActivity(), SurfaceHolder.Callback {
    private lateinit var surfaceView: MoUISurfaceView
    private lateinit var platformViewController: MoUIPlatformViewController
    private lateinit var pluginCapabilities: MoUIShellPluginCapabilities
    private var attached = false
    private var started = false
    private var fullscreen = false
    private var statusBar = STATUS_BAR_AUTO
    private var hasLastTouchPoint = false
    private var lastTouchX = 0f
    private var lastTouchY = 0f
    private var frameLoopRunning = false

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (frameLoopRunning && attached && started) {
                MoUINativeBridge.frameTick(frameTimeNanos / 1_000_000.0)
                surfaceView.applyHostUpdates(
                    MoUINativeBridge.takeHostUpdates(),
                    platformViewController,
                )
                Choreographer.getInstance().postFrameCallback(this)
            } else {
                frameLoopRunning = false
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        loadNativeLibraryFromManifest()
        pluginCapabilities = MoUIShellPluginCapabilities.forIntent(intent)
        MoUIGeneratedPluginRegistry.install(this, pluginCapabilities)
        Log.i(LOG_TAG, "moui-shell renderer status=${MoUINativeBridge.rendererStatusJson()}")
        fullscreen = manifestBoolean(META_FULLSCREEN, false)
        statusBar = manifestStatusBar()
        configureWindow()

        val root = FrameLayout(this)
        surfaceView = MoUISurfaceView(this, pluginCapabilities)
        surfaceView.holder.addCallback(this)
        surfaceView.setOnTouchListener { _, event ->
            if (attached) dispatchMotionEventToRuntime(event)
            true
        }
        val overlay = FrameLayout(this).apply {
            isClickable = false
            isFocusable = false
        }
        platformViewController = MoUIPlatformViewController(overlay)
        val fill = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        root.addView(surfaceView, fill)
        root.addView(overlay, FrameLayout.LayoutParams(fill))
        setContentView(root)
        surfaceView.requestFocus()
        Log.i(
            LOG_TAG,
            "moui-shell managed-shell language=kotlin activity=ComponentActivity overlay=FrameLayout",
        )
    }

    override fun onStart() {
        super.onStart()
        started = true
        startFrameLoop()
    }

    override fun onStop() {
        started = false
        stopFrameLoop()
        Log.i(LOG_TAG, "moui-shell lifecycle paused reason=stop")
        super.onStop()
    }

    override fun onDestroy() {
        stopFrameLoop()
        detachSurface("destroy")
        if (isFinishing && !isChangingConfigurations) {
            val destroyed = MoUINativeBridge.destroyApplication()
            Log.i(LOG_TAG, "moui-shell application destroy result=$destroyed")
        }
        super.onDestroy()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) configureWindow()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (!attached) return
        surfaceView.requestLayout()
        surfaceView.post {
            if (!attached) return@post
            val width = surfaceView.width.coerceAtLeast(1)
            val height = surfaceView.height.coerceAtLeast(1)
            MoUINativeBridge.resize(width, height, density())
            Log.i(
                LOG_TAG,
                "moui-shell resize width=$width height=$height orientation=${newConfig.orientation}",
            )
        }
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        if (attached) detachSurface("surface-replaced")
        val width = surfaceView.width.coerceAtLeast(1)
        val height = surfaceView.height.coerceAtLeast(1)
        attached = MoUINativeBridge.attachSurface(holder.surface, width, height, density())
        Log.i(
            LOG_TAG,
            "moui-shell lifecycle attach width=$width height=$height attached=$attached",
        )
        startFrameLoop()
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        if (!attached) return
        val surfaceWidth = width.coerceAtLeast(1)
        val surfaceHeight = height.coerceAtLeast(1)
        MoUINativeBridge.resize(surfaceWidth, surfaceHeight, density())
        Log.i(LOG_TAG, "moui-shell resize width=$surfaceWidth height=$surfaceHeight")
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        stopFrameLoop()
        detachSurface("surface-destroyed")
    }

    private fun startFrameLoop() {
        if (!frameLoopRunning && attached && started) {
            frameLoopRunning = true
            Choreographer.getInstance().postFrameCallback(frameCallback)
        }
    }

    private fun stopFrameLoop() {
        if (frameLoopRunning) {
            frameLoopRunning = false
            Choreographer.getInstance().removeFrameCallback(frameCallback)
        }
    }

    private fun detachSurface(reason: String) {
        if (attached) {
            MoUINativeBridge.detachSurface()
            attached = false
        }
        if (::platformViewController.isInitialized) platformViewController.clear()
        if (::surfaceView.isInitialized) surfaceView.clearHostState()
        Log.i(LOG_TAG, "moui-shell lifecycle detach reason=$reason")
    }

    private fun dispatchMotionEventToRuntime(event: MotionEvent) {
        if (event.pointerCount == 0) return
        val phase = pointerPhase(event.actionMasked)
        val pointerIndex = event.actionIndex.coerceIn(0, event.pointerCount - 1)
        val x = event.getX(pointerIndex).toDouble()
        val y = event.getY(pointerIndex).toDouble()
        dispatchScrollPhase(phase, x, y)
        MoUINativeBridge.dispatchPointer(phase, x, y, event.eventTime.toDouble())
        Log.i(LOG_TAG, "moui-shell input pointer phase=$phase x=$x y=$y")
    }

    private fun dispatchScrollPhase(phase: Int, x: Double, y: Double) {
        when {
            phase == 0 -> {
                hasLastTouchPoint = true
                lastTouchX = x.toFloat()
                lastTouchY = y.toFloat()
                MoUINativeBridge.dispatchScroll(x, y, 0.0, 0.0, 0)
            }
            phase == 1 && hasLastTouchPoint -> {
                val deltaX = x - lastTouchX
                val deltaY = y - lastTouchY
                lastTouchX = x.toFloat()
                lastTouchY = y.toFloat()
                MoUINativeBridge.dispatchScroll(x, y, deltaX, deltaY, 1)
                Log.i(LOG_TAG, "moui-shell input scroll dx=$deltaX dy=$deltaY")
            }
            phase == 2 || phase == 3 -> {
                MoUINativeBridge.dispatchScroll(x, y, 0.0, 0.0, if (phase == 2) 2 else 3)
                hasLastTouchPoint = false
            }
        }
    }

    private fun configureWindow() {
        WindowCompat.setDecorFitsSystemWindows(window, !fullscreen)
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        if (fullscreen) {
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller.hide(WindowInsetsCompat.Type.navigationBars())
        } else {
            controller.show(WindowInsetsCompat.Type.navigationBars())
        }
        val hideStatusBar = when (statusBar) {
            STATUS_BAR_HIDDEN -> true
            STATUS_BAR_VISIBLE -> false
            else -> fullscreen
        }
        if (hideStatusBar) {
            controller.hide(WindowInsetsCompat.Type.statusBars())
        } else {
            controller.show(WindowInsetsCompat.Type.statusBars())
        }
    }

    private fun density(): Double = resources.displayMetrics.density.toDouble()

    private fun loadNativeLibraryFromManifest() {
        val library = manifestString(META_NATIVE_LIBRARY)
            ?: error("missing manifest metadata $META_NATIVE_LIBRARY")
        System.loadLibrary(library)
    }

    private fun manifestString(key: String): String? = activityInfo().metaData?.getString(key)

    private fun manifestBoolean(key: String, fallback: Boolean): Boolean =
        activityInfo().metaData?.getBoolean(key, fallback) ?: fallback

    private fun manifestStatusBar(): String = when (val value = manifestString(META_STATUS_BAR)) {
        null, STATUS_BAR_AUTO -> STATUS_BAR_AUTO
        STATUS_BAR_VISIBLE -> STATUS_BAR_VISIBLE
        STATUS_BAR_HIDDEN -> STATUS_BAR_HIDDEN
        else -> error("invalid manifest metadata $META_STATUS_BAR=$value")
    }

    private fun activityInfo(): ActivityInfo =
        try {
            packageManager.getActivityInfo(componentName, PackageManager.GET_META_DATA)
        } catch (error: PackageManager.NameNotFoundException) {
            throw IllegalStateException("activity metadata unavailable", error)
        }

    companion object {
        private const val LOG_TAG = "MoUIShell"
        private const val META_NATIVE_LIBRARY = "dev.wzzc.moui.NATIVE_LIBRARY"
        private const val META_FULLSCREEN = "dev.wzzc.moui.FULLSCREEN"
        private const val META_STATUS_BAR = "dev.wzzc.moui.STATUS_BAR"
        private const val STATUS_BAR_AUTO = "auto"
        private const val STATUS_BAR_VISIBLE = "visible"
        private const val STATUS_BAR_HIDDEN = "hidden"

        private fun pointerPhase(action: Int): Int = when (action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> 0
            MotionEvent.ACTION_MOVE -> 1
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP -> 2
            MotionEvent.ACTION_CANCEL -> 3
            else -> 1
        }
    }
}
