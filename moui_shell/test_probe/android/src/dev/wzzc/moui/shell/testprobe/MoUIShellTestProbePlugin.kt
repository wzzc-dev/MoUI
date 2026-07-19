package dev.wzzc.moui.shell.testprobe

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Color
import android.graphics.RectF
import android.util.Log
import android.view.View
import android.widget.TextView
import dev.wzzc.moui.shell.MoUIHostServiceCompletion
import dev.wzzc.moui.shell.MoUIHostServiceHandler
import dev.wzzc.moui.shell.MoUIHostServiceRequest
import dev.wzzc.moui.shell.MoUIHostServiceTask
import dev.wzzc.moui.shell.MoUIHostServices
import dev.wzzc.moui.shell.MoUIShellPlugin
import dev.wzzc.moui.shell.MoUIShellPluginCapabilities
import dev.wzzc.moui.shell.MoUIPluginSubscription
import dev.wzzc.moui.shell.MoUIPlatformViewEventSink
import dev.wzzc.moui.shell.MoUIPlatformViewFactory
import dev.wzzc.moui.shell.MoUIPlatformViewPlacement
import dev.wzzc.moui.shell.MoUIPlatformViews
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

private const val PLUGIN_ID = "dev.wzzc.moui.shell.test-probe"
private const val PLATFORM_VIEW_KIND = "$PLUGIN_ID.view"
private const val HOST_CHANNEL = "$PLUGIN_ID.channel"
private const val TEST_PROBE_GATE = "moui.shell.testProbe"
private const val SERVICE_TEXT_LABEL = "Service probe text"
private const val SERVICE_ACTION_LABEL = "Activate service probe"
private const val SERVICE_PROBE_TEXT = "ime-shell-probe"
private const val LOG_TAG = "MoUIShell"

private object ProbeState {
    val platformViewCreate = AtomicInteger(0)
    val platformViewResize = AtomicInteger(0)
    val platformViewClip = AtomicInteger(0)
    val platformViewEvent = AtomicInteger(0)
    val platformViewDispose = AtomicInteger(0)
    val hostChannelSuccess = AtomicInteger(0)
    val hostChannelError = AtomicInteger(0)
    val hostChannelCancel = AtomicInteger(0)
    val hostChannelExactlyOnce = AtomicInteger(0)
    val hostChannelLateAfterDispose = AtomicInteger(0)
    val serviceSmokeFired = AtomicInteger(0)
    val serviceSmokeCompleted = AtomicInteger(0)

    fun increment(counter: AtomicInteger) {
        counter.incrementAndGet()
        Log.i(LOG_TAG, "moui-shell test-probe snapshot=${snapshot()}")
    }

    fun snapshot(): String = JSONObject()
        .put("platformViewCreate", platformViewCreate.get())
        .put("platformViewResize", platformViewResize.get())
        .put("platformViewClip", platformViewClip.get())
        .put("platformViewEvent", platformViewEvent.get())
        .put("platformViewDispose", platformViewDispose.get())
        .put("hostChannelSuccess", hostChannelSuccess.get())
        .put("hostChannelError", hostChannelError.get())
        .put("hostChannelCancel", hostChannelCancel.get())
        .put("hostChannelExactlyOnce", hostChannelExactlyOnce.get())
        .put("hostChannelLateAfterDispose", hostChannelLateAfterDispose.get())
        .put("serviceSmokeFired", serviceSmokeFired.get())
        .put("serviceSmokeCompleted", serviceSmokeCompleted.get())
        .toString()
}

private object ProbeServiceSmoke {
    private val installed = AtomicBoolean(false)
    private val fired = AtomicBoolean(false)
    private var subscription: MoUIPluginSubscription? = null

    fun install(context: Context, capabilities: MoUIShellPluginCapabilities) {
        if (!installed.compareAndSet(false, true)) return
        val applicationContext = context.applicationContext
        subscription = capabilities.semantics.observe { snapshot, runtimeInput ->
            if (!capabilities.launchOptions.isEnabled(TEST_PROBE_GATE) || fired.get()) {
                return@observe
            }
            val textField = snapshot.nodes.firstOrNull {
                it.label == SERVICE_TEXT_LABEL && it.role == "TextField"
            } ?: return@observe
            val action = snapshot.nodes.firstOrNull {
                it.label == SERVICE_ACTION_LABEL && it.role == "Button"
            } ?: return@observe
            if (!fired.compareAndSet(false, true)) return@observe
            ProbeState.increment(ProbeState.serviceSmokeFired)
            Log.i(LOG_TAG, "moui-shell service smoke begin")
            val textFocusAccepted = runtimeInput.dispatchAccessibility(textField.elementId, 1)
            var accepted = textFocusAccepted
            val setTextAccepted = runtimeInput.dispatchAccessibility(
                textField.elementId,
                2,
                SERVICE_PROBE_TEXT,
            )
            accepted = setTextAccepted && accepted
            val imeCommitAccepted = runtimeInput.dispatchTextInput(1, SERVICE_PROBE_TEXT, 0, 0)
            accepted = imeCommitAccepted && accepted
            if (imeCommitAccepted) Log.i(LOG_TAG, "moui-shell service ime edit kind=commit")
            val selectionAccepted = runtimeInput.dispatchTextInput(
                2,
                "",
                0,
                SERVICE_PROBE_TEXT.length,
            )
            accepted = selectionAccepted && accepted
            val copyAccepted = runtimeInput.dispatchCommand(0)
            accepted = copyAccepted && accepted
            if (copyAccepted) Log.i(LOG_TAG, "moui-shell service smoke copy")
            val clipboard = applicationContext.getSystemService(ClipboardManager::class.java)
            clipboard?.setPrimaryClip(ClipData.newPlainText("MoUI", "clipboard-service-probe"))
            accepted = clipboard != null && accepted
            val pasteAccepted = runtimeInput.dispatchCommand(2)
            accepted = pasteAccepted && accepted
            if (pasteAccepted) Log.i(LOG_TAG, "moui-shell service smoke paste")
            val cutAccepted = runtimeInput.dispatchCommand(1)
            accepted = cutAccepted && accepted
            if (cutAccepted) Log.i(LOG_TAG, "moui-shell service smoke cut")
            val actionFocusAccepted = runtimeInput.dispatchAccessibility(action.elementId, 1)
            accepted = actionFocusAccepted && accepted
            if (actionFocusAccepted) {
                Log.i(LOG_TAG, "moui-shell service accessibility focus id=${action.elementId}")
            }
            val actionActivateAccepted = runtimeInput.dispatchAccessibility(action.elementId, 0)
            accepted = actionActivateAccepted && accepted
            if (actionActivateAccepted) {
                Log.i(LOG_TAG, "moui-shell service accessibility action=activate id=${action.elementId}")
            }
            if (accepted && runtimeInput.isActive) {
                ProbeState.increment(ProbeState.serviceSmokeCompleted)
            }
            Log.i(LOG_TAG, "moui-shell service smoke end accepted=${if (accepted) 1 else 0}")
        }
    }
}

private class ProbeTextView(
    context: Context,
    val events: MoUIPlatformViewEventSink,
) : TextView(context) {
    var lastFrame: RectF? = null
    var sentReady = false

    init {
        text = "MoUI test probe"
        setTextColor(Color.WHITE)
        setBackgroundColor(Color.rgb(22, 101, 52))
        contentDescription = "MoUI test probe PlatformView"
        setOnClickListener {
            if (events.dispatch("activate", "android", ProbeState.snapshot(), true)) {
                ProbeState.increment(ProbeState.platformViewEvent)
            }
        }
    }
}

private object ProbePlatformViewFactory : MoUIPlatformViewFactory {
    override fun create(context: Context, id: String, sink: MoUIPlatformViewEventSink): View {
        ProbeState.increment(ProbeState.platformViewCreate)
        return ProbeTextView(context, sink).apply { tag = id }
    }

    override fun update(view: View, placement: MoUIPlatformViewPlacement) {
        val probe = view as ProbeTextView
        val previous = probe.lastFrame
        if (previous == null || previous.width() != placement.frame.width() ||
            previous.height() != placement.frame.height()
        ) {
            ProbeState.increment(ProbeState.platformViewResize)
        }
        if (placement.clip != null) ProbeState.increment(ProbeState.platformViewClip)
        probe.lastFrame = RectF(placement.frame)
        probe.text = placement.properties["label"] ?: "MoUI test probe"
        if (!probe.sentReady) {
            probe.sentReady = true
            if (probe.events.dispatch("ready", placement.id, ProbeState.snapshot(), true)) {
                ProbeState.increment(ProbeState.platformViewEvent)
            }
        }
    }

    override fun dispose(view: View) {
        val probe = view as ProbeTextView
        ProbeState.increment(ProbeState.platformViewDispose)
        probe.events.dispatch("disposed", placementValue(view), ProbeState.snapshot(), false)
        probe.setOnClickListener(null)
    }

    private fun placementValue(view: View): String = view.tag?.toString() ?: ""
}

private class ProbePendingTask(
    private val completion: MoUIHostServiceCompletion,
    private val kind: Kind,
) : MoUIHostServiceTask {
    private val cancelled = AtomicBoolean(false)

    enum class Kind {
        CANCEL,
        LATE_AFTER_DISPOSE,
    }

    override fun cancel() {
        if (!cancelled.compareAndSet(false, true)) return
        when (kind) {
            Kind.CANCEL -> ProbeState.increment(ProbeState.hostChannelCancel)
            Kind.LATE_AFTER_DISPOSE -> if (!completion.ok("late-after-dispose")) {
                ProbeState.increment(ProbeState.hostChannelLateAfterDispose)
            }
        }
    }
}

private object ProbeHostServiceHandler : MoUIHostServiceHandler {
    override fun handle(
        request: MoUIHostServiceRequest,
        completion: MoUIHostServiceCompletion,
    ): MoUIHostServiceTask? = when (request.operation) {
        "success", "echo" -> {
            if (completion.ok(request.payload)) {
                ProbeState.increment(ProbeState.hostChannelSuccess)
            }
            null
        }
        "snapshot" -> {
            completion.ok(ProbeState.snapshot())
            null
        }
        "error" -> {
            if (completion.error(request.payload.ifEmpty { "test-probe error" })) {
                ProbeState.increment(ProbeState.hostChannelError)
            }
            null
        }
        "exactly-once" -> {
            val firstAccepted = completion.ok("first")
            val duplicateAccepted = completion.error("duplicate")
            if (firstAccepted && !duplicateAccepted) {
                ProbeState.increment(ProbeState.hostChannelExactlyOnce)
            }
            null
        }
        "cancel" -> ProbePendingTask(completion, ProbePendingTask.Kind.CANCEL)
        "late-after-dispose" -> ProbePendingTask(completion, ProbePendingTask.Kind.LATE_AFTER_DISPOSE)
        else -> {
            completion.unavailable("unknown test-probe operation: ${request.operation}")
            null
        }
    }
}

class MoUIShellTestProbePlugin : MoUIShellPlugin {
    override val id: String = PLUGIN_ID

    override fun install(context: Context) {
        context.applicationContext
        MoUIPlatformViews.register(PLATFORM_VIEW_KIND, ProbePlatformViewFactory)
        MoUIHostServices.register(HOST_CHANNEL, ProbeHostServiceHandler)
    }

    override fun install(context: Context, capabilities: MoUIShellPluginCapabilities) {
        install(context)
        ProbeServiceSmoke.install(context, capabilities)
    }
}
