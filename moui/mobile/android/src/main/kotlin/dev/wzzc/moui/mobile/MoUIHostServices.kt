package dev.wzzc.moui.mobile

import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

data class MoUIHostServiceRequest(
    val channel: String,
    val operation: String,
    val payload: String,
)

enum class MoUIHostServiceStatus(internal val wireValue: String) {
    OK("ok"),
    ERROR("error"),
    UNAVAILABLE("unavailable"),
}

data class MoUIHostServiceResponse(
    val status: MoUIHostServiceStatus,
    val payload: String = "",
)

fun interface MoUIHostServiceHandler {
    fun handle(
        request: MoUIHostServiceRequest,
        completion: MoUIHostServiceCompletion,
    ): MoUIHostServiceTask?
}

fun interface MoUIHostServiceTask {
    fun cancel()
}

class MoUIHostServiceCompletion internal constructor(
    private val dispatch: (MoUIHostServiceResponse) -> Unit,
) {
    private val completed = AtomicBoolean(false)

    @JvmOverloads
    fun ok(payload: String = ""): Boolean =
        complete(MoUIHostServiceResponse(MoUIHostServiceStatus.OK, payload))

    @JvmOverloads
    fun error(payload: String = ""): Boolean =
        complete(MoUIHostServiceResponse(MoUIHostServiceStatus.ERROR, payload))

    @JvmOverloads
    fun unavailable(payload: String = ""): Boolean =
        complete(MoUIHostServiceResponse(MoUIHostServiceStatus.UNAVAILABLE, payload))

    @JvmOverloads
    fun cancel(payload: String = "platform channel request cancelled"): Boolean =
        unavailable(payload)

    fun complete(response: MoUIHostServiceResponse): Boolean {
        if (!completed.compareAndSet(false, true)) return false
        dispatch(response)
        return true
    }

    internal fun invalidate() {
        completed.set(true)
    }

    internal val isFinished: Boolean
        get() = completed.get()
}

object MoUIHostServices {
    private data class RequestKey(val generation: Int, val requestId: Int)

    private class PendingRequest(
        val completion: MoUIHostServiceCompletion,
    ) {
        private var task: MoUIHostServiceTask? = null

        @Synchronized
        fun install(nextTask: MoUIHostServiceTask?) {
            if (completion.isFinished) {
                nextTask?.cancel()
                return
            }
            task = nextTask
            if (completion.isFinished) {
                task = null
                nextTask?.cancel()
            }
        }

        @Synchronized
        fun cancel() {
            completion.invalidate()
            task?.cancel()
            task = null
        }
    }

    private val handlers = ConcurrentHashMap<String, MoUIHostServiceHandler>()
    private val pending = ConcurrentHashMap<RequestKey, PendingRequest>()
    private val mainHandler = Handler(Looper.getMainLooper())

    @JvmStatic
    fun register(channel: String, handler: MoUIHostServiceHandler) {
        require(channel.isNotBlank()) { "host service channel must not be blank" }
        require(!channel.startsWith("moui.")) { "moui.* host service channels are reserved" }
        require(handlers.putIfAbsent(channel, handler) == null) {
            "host service channel is already registered: $channel"
        }
    }

    @JvmStatic
    fun unregister(channel: String) {
        handlers.remove(channel)
    }

    internal fun reset() {
        for ((key, request) in pending.entries) {
            if (!pending.remove(key, request)) continue
            request.cancel()
        }
    }

    internal fun dispatch(update: JSONObject, generation: Int?): Boolean {
        if (generation == null || generation <= 0) {
            Log.e(LOG_TAG, "platform channel request is missing Host Wire session generation")
            return false
        }
        val requestId = update.optInt("id", 0)
        if (requestId <= 0) {
            Log.e(LOG_TAG, "platform channel request has invalid id=$requestId")
            return false
        }
        val key = RequestKey(generation, requestId)
        val completion = MoUIHostServiceCompletion { response ->
            finish(key, response)
        }
        val requestState = PendingRequest(completion)
        if (pending.putIfAbsent(key, requestState) != null) {
            Log.w(LOG_TAG, "duplicate platform channel request id=$requestId generation=$generation")
            return false
        }
        val payload = update.optJSONObject("payload")
        val channel = payload?.opt("channel") as? String
        val operation = payload?.opt("operation") as? String
        val body = payload?.opt("payload") as? String
        if (channel.isNullOrBlank() || operation.isNullOrBlank() || body == null) {
            return completion.error("invalid platform channel request")
        }
        val request = MoUIHostServiceRequest(channel, operation, body)
        val handler = handlers[channel]
            ?: return completion.unavailable("platform channel is unavailable: $channel")
        return try {
            val task = handler.handle(request, completion)
            if (pending[key] === requestState && !completion.isFinished) {
                requestState.install(task)
            } else {
                task?.cancel()
            }
            true
        } catch (error: Exception) {
            Log.e(LOG_TAG, "platform channel handler failed channel=$channel", error)
            completion.error("platform channel handler failed: $channel")
        }
    }

    private fun finish(key: RequestKey, response: MoUIHostServiceResponse) {
        if (pending.remove(key) == null) return
        dispatchResponse(key.generation, key.requestId, response)
    }

    private fun dispatchResponse(
        generation: Int,
        requestId: Int,
        response: MoUIHostServiceResponse,
    ) {
        val send = Runnable {
            runCatching {
                val encodedResponse = JSONObject()
                    .put("kind", "platform-channel")
                    .put("requestId", requestId)
                    .put("status", response.status.wireValue)
                    .put("payload", response.payload)
                val envelope = JSONObject()
                    .put("schemaVersion", HOST_WIRE_SCHEMA_VERSION)
                    .put("sessionGeneration", generation)
                    .put("response", encodedResponse)
                val accepted = MoUINativeBridge.dispatchHostResponseEnvelope(envelope.toString())
                if (!accepted) {
                    Log.w(
                        LOG_TAG,
                        "platform channel response rejected id=$requestId generation=$generation",
                    )
                }
            }.onFailure { error ->
                Log.e(LOG_TAG, "failed to dispatch platform channel response id=$requestId", error)
            }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) send.run() else mainHandler.post(send)
    }

    private const val LOG_TAG = "MoUIMobile"
    private const val HOST_WIRE_SCHEMA_VERSION = 1
}
