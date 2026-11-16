package dev.zeekr.bluetooth_low_energy_android

import java.util.ArrayDeque
import kotlin.math.ceil

/** One opt-in recording window. All calls run on the Android main executor.
 * Reply timing includes the return trip from Dart; it is an upper bound on
 * delivery to the Dart handler, NOT sensor latency or one-way channel delay.
 */
internal class DeliveryWindow(private val nowNs: () -> Long) {
    private val startedNs = nowNs()
    private var stoppedNs: Long? = null
    private var previousReceiptNs: Long? = null
    private var received = 0L
    private var replied = 0L
    private var failed = 0L
    private val intervals = ArrayDeque<Double>()
    private val dispatch = ArrayDeque<Double>()
    private val channelRoundtrip = ArrayDeque<Double>()
    private val callbackRoundtrip = ArrayDeque<Double>()

    fun notification(receivedAtNs: Long): (Boolean) -> Unit {
        val sentAtNs = nowNs()
        received++
        previousReceiptNs?.let { append(intervals, receivedAtNs - it) }
        previousReceiptNs = receivedAtNs
        append(dispatch, sentAtNs - receivedAtNs)
        var completed = false
        return reply@{ success ->
            if (stoppedNs != null || completed) return@reply
            completed = true
            replied++
            if (success) {
                val replyAtNs = nowNs()
                append(channelRoundtrip, replyAtNs - sentAtNs)
                append(callbackRoundtrip, replyAtNs - receivedAtNs)
            } else {
                failed++
            }
        }
    }

    fun stop() { if (stoppedNs == null) stoppedNs = nowNs() }

    fun snapshot(): Map<String, Any?> = mapOf(
        "duration_ms" to ((stoppedNs ?: nowNs()) - startedNs) / 1_000_000.0,
        "weight_notification_count" to received,
        "flutter_reply_count" to replied,
        "flutter_reply_error_count" to failed,
        "pending_replies_at_stop" to received - replied,
        "native_interval_ms" to stats(intervals),
        "main_dispatch_ms" to stats(dispatch),
        "platform_channel_roundtrip_ms" to stats(channelRoundtrip),
        "callback_to_flutter_reply_ms" to stats(callbackRoundtrip),
    )

    private fun append(values: ArrayDeque<Double>, ns: Long) {
        if (values.size == 600) values.removeFirst()
        values.addLast(ns.coerceAtLeast(0) / 1_000_000.0)
    }

    private fun stats(values: ArrayDeque<Double>): Map<String, Any?> {
        if (values.isEmpty()) return mapOf("count" to 0)
        val sorted = values.sorted()
        return mapOf("count" to values.size, "mean" to values.average(),
            "p95" to sorted[ceil(sorted.size * .95).toInt() - 1], "max" to sorted.last())
    }
}
