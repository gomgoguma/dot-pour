package dev.zeekr.bluetooth_low_energy_android

import java.util.ArrayDeque
import java.util.concurrent.Executor

/** Serial delivery with backpressure across BOTH the main executor and Dart.
 * Only adjacent, complete valid weight frames can replace one another. Other
 * packets are ordering barriers, so ACKs and fragmented frames are preserved.
 */
internal class NotificationPump<T>(
    private val executor: Executor,
    private val send: (T, (Boolean) -> Unit) -> Unit,
) {
    private data class Entry<T>(val value: T, val replaceable: Boolean)
    private val queue = ArrayDeque<Entry<T>>()
    private var scheduled = false
    private var inFlight = false
    private var closed = false
    private var received = 0L
    private var forwarded = 0L
    private var coalesced = 0L
    private var errors = 0L
    private var discarded = 0L
    private var peakQueued = 0

    @Synchronized
    fun offer(value: T, replaceable: Boolean) {
        if (closed) return
        received++
        if (replaceable && queue.peekLast()?.replaceable == true) {
            queue.removeLast()
            coalesced++
        }
        queue.addLast(Entry(value, replaceable))
        peakQueued = maxOf(peakQueued, queue.size)
        schedule()
    }

    private fun schedule() {
        if (closed || scheduled || inFlight || queue.isEmpty()) return
        scheduled = true
        executor.execute(::drain)
    }

    private fun drain() {
        val entry = synchronized(this) {
            scheduled = false
            if (closed || inFlight || queue.isEmpty()) return
            inFlight = true
            forwarded++
            queue.removeFirst()
        }
        var completed = false
        val done: (Boolean) -> Unit = { success ->
            synchronized(this) {
                if (!completed) {
                    completed = true
                    inFlight = false
                    if (!success) errors++
                    schedule()
                }
            }
        }
        try { send(entry.value, done) } catch (_: Exception) { done(false) }
    }

    @Synchronized
    fun close() {
        closed = true
        discarded += queue.size
        queue.clear()
    }

    @Synchronized
    fun snapshot(): Map<String, Any> = mapOf(
        "scope" to "connection lifetime; all uplink packets",
        "received" to received, "forwarded" to forwarded,
        "weights_coalesced" to coalesced, "delivery_errors" to errors,
        "discarded_on_close" to discarded, "queued" to queue.size,
        "peak_queued" to peakQueued, "in_flight" to inFlight, "closed" to closed,
    )
}

internal object DotWeightFrame {
    fun replaceable(value: ByteArray): Boolean {
        if (value.size != 17 || value[0] != 0xA5.toByte() || value[1] != 0x5A.toByte() ||
            value[2] != 1.toByte() || value[3] != 1.toByte() ||
            value[4] != 0.toByte() || value[5] != 9.toByte() || value[14] != 0.toByte()) return false
        val crc = ((value[15].toInt() and 255) shl 8) or (value[16].toInt() and 255)
        if (crc == 0) return true // Reserved-CRC firmware, as in the app decoder.
        var computed = 0xFFFF
        for (i in 0 until 15) {
            computed = computed xor (value[i].toInt() and 255)
            repeat(8) { computed = if (computed and 1 != 0) (computed ushr 1) xor 0xA001 else computed ushr 1 }
        }
        return crc == computed
    }
}
