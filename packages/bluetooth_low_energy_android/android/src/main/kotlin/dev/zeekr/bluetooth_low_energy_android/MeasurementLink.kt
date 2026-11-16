package dev.zeekr.bluetooth_low_energy_android

import java.util.ArrayDeque

/** Bounded measurements of the Android callback path, not sensor-to-screen lag.
 * All state is accessed on the manager's main executor. The receipt timestamp
 * is taken earlier, on the Bluetooth callback thread.
 */
internal class MeasurementLink(
    private val requestPriority: (Boolean) -> Boolean,
    private val nowNs: () -> Long = System::nanoTime,
) {
    private val intervals = ArrayDeque<Double>()
    private val dispatchDelays = ArrayDeque<Double>()
    private var lastReceiptNs: Long? = null
    private var count = 0L
    private var streaming = false
    private var requestAccepted: Boolean? = null

    fun setStreaming(enabled: Boolean) {
        streaming = enabled
        // Connection tuning must never prevent a usable scale from connecting.
        requestAccepted = try {
            requestPriority(enabled)
        } catch (_: Exception) {
            false
        }
    }

    fun notification(value: ByteArray, receivedAtNs: Long) {
        // Stats cover complete weight notifications only, excluding command
        // replies/ACKs. This does not alter the application's packet decoder.
        if (value.size != 17 || value[0] != 0xA5.toByte() ||
            value[1] != 0x5A.toByte() || value[2] != 1.toByte() ||
            value[3] != 1.toByte() || value[4] != 0.toByte() ||
            value[5] != 9.toByte()) return
        val previous = lastReceiptNs
        if (previous != null && receivedAtNs >= previous) {
            append(intervals, (receivedAtNs - previous) / 1_000_000.0)
        }
        append(dispatchDelays, (nowNs() - receivedAtNs).coerceAtLeast(0) / 1_000_000.0)
        lastReceiptNs = receivedAtNs
        count++
    }

    fun snapshot(): Map<String, Any?> = mapOf(
        "requested_priority" to if (streaming) "high" else "balanced",
        "priority_request_accepted" to requestAccepted,
        "weight_notification_count" to count,
        "window_size" to dispatchDelays.size,
        "native_interval_mean_ms" to mean(intervals),
        "native_interval_max_ms" to intervals.maxOrNull(),
        "main_dispatch_mean_ms" to mean(dispatchDelays),
        "main_dispatch_max_ms" to dispatchDelays.maxOrNull(),
        "last_notification_age_ms" to lastReceiptNs?.let {
            (nowNs() - it).coerceAtLeast(0) / 1_000_000.0
        },
    )

    private fun append(values: ArrayDeque<Double>, value: Double) {
        if (values.size == 64) values.removeFirst()
        values.addLast(value)
    }

    private fun mean(values: ArrayDeque<Double>): Double? =
        if (values.isEmpty()) null else values.average()
}
