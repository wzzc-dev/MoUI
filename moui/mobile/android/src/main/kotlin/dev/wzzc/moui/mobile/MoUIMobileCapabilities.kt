package dev.wzzc.moui.mobile

import android.content.Intent
import android.os.Looper
import android.util.Log

class MoUILaunchOptions internal constructor() {
    @Volatile
    private var values: Map<String, String> = emptyMap()

    fun value(key: String): String? = values[key]

    fun isEnabled(key: String): Boolean = when (value(key)?.trim()?.lowercase()) {
        "1", "true", "yes", "on" -> true
        else -> false
    }

    internal fun replace(intent: Intent?) {
        val extras = intent?.extras
        values = extras?.keySet()?.mapNotNull { key ->
            intent.getStringExtra(key)?.let { value -> key to value }
        }?.toMap() ?: emptyMap()
    }
}

data class MoUISemanticsNodeSnapshot(
    val elementId: Int,
    val role: String,
    val label: String,
)

data class MoUISemanticsSnapshot(
    val sessionGeneration: Int,
    val revision: Int,
    val nodes: List<MoUISemanticsNodeSnapshot>,
)

fun interface MoUISemanticsObserver {
    fun onSemantics(
        snapshot: MoUISemanticsSnapshot,
        runtimeInput: MoUIRuntimeInputDispatcher,
    )
}

fun interface MoUIPluginSubscription {
    fun dispose()
}

class MoUISemanticsCapability internal constructor(
    private val owner: MoUIMobilePluginCapabilities,
) {
    fun observe(observer: MoUISemanticsObserver): MoUIPluginSubscription = owner.observe(observer)
}

class MoUIRuntimeInputDispatcher internal constructor(
    private val owner: MoUIMobilePluginCapabilities,
    val sessionGeneration: Int,
    private val epoch: Long,
) {
    val isActive: Boolean
        get() = owner.isCurrent(sessionGeneration, epoch)

    fun dispatchAccessibility(elementId: Int, action: Int, value: String = ""): Boolean =
        owner.dispatch(sessionGeneration, epoch) {
            MoUINativeBridge.dispatchAccessibility(elementId, action, value)
        }

    fun dispatchTextInput(kind: Int, text: String, start: Int, end: Int): Boolean =
        owner.dispatch(sessionGeneration, epoch) {
            MoUINativeBridge.dispatchTextInput(kind, text, start, end)
        }

    fun dispatchCommand(kind: Int): Boolean = owner.dispatch(sessionGeneration, epoch) {
        MoUINativeBridge.dispatchCommand(kind)
    }
}

class MoUIMobilePluginCapabilities private constructor() {
    val launchOptions: MoUILaunchOptions = MoUILaunchOptions()
    val semantics: MoUISemanticsCapability = MoUISemanticsCapability(this)

    private val lock = Any()
    private val observers = linkedMapOf<Any, MoUISemanticsObserver>()
    private var generation: Int? = null
    private var epoch: Long = 0
    private var semanticsRevision: Int = -1

    internal fun configure(intent: Intent?): MoUIMobilePluginCapabilities {
        launchOptions.replace(intent)
        resetSession()
        return this
    }

    internal fun activateSession(nextGeneration: Int) {
        if (nextGeneration <= 0) {
            resetSession()
            return
        }
        synchronized(lock) {
            if (generation == nextGeneration) return
            generation = nextGeneration
            epoch += 1
            semanticsRevision = -1
        }
    }

    internal fun publishSemantics(
        sessionGeneration: Int,
        revision: Int,
        nodes: List<MoUISemanticsNodeSnapshot>,
    ) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            Log.e(LOG_TAG, "plugin semantics snapshot rejected off the main thread")
            return
        }
        val delivery = synchronized(lock) {
            if (generation != sessionGeneration || revision <= semanticsRevision) return
            semanticsRevision = revision
            val dispatcher = MoUIRuntimeInputDispatcher(this, sessionGeneration, epoch)
            Triple(
                MoUISemanticsSnapshot(sessionGeneration, revision, nodes.toList()),
                dispatcher,
                observers.values.toList(),
            )
        }
        for (observer in delivery.third) {
            runCatching { observer.onSemantics(delivery.first, delivery.second) }
                .onFailure { Log.e(LOG_TAG, "plugin semantics observer failed", it) }
        }
    }

    internal fun resetSession() {
        synchronized(lock) {
            generation = null
            epoch += 1
            semanticsRevision = -1
        }
    }

    internal fun observe(observer: MoUISemanticsObserver): MoUIPluginSubscription {
        val token = Any()
        synchronized(lock) { observers[token] = observer }
        return MoUIPluginSubscription { synchronized(lock) { observers.remove(token) } }
    }

    internal fun isCurrent(sessionGeneration: Int, dispatcherEpoch: Long): Boolean =
        Looper.myLooper() == Looper.getMainLooper() && synchronized(lock) {
            generation == sessionGeneration && epoch == dispatcherEpoch
        }

    internal inline fun dispatch(
        sessionGeneration: Int,
        dispatcherEpoch: Long,
        operation: () -> Boolean,
    ): Boolean = if (isCurrent(sessionGeneration, dispatcherEpoch)) operation() else false

    companion object {
        private const val LOG_TAG = "MoUIMobile"
        private val shared = MoUIMobilePluginCapabilities()

        internal fun forIntent(intent: Intent?): MoUIMobilePluginCapabilities = shared.configure(intent)
    }
}
