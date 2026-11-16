package dev.zeekr.bluetooth_low_energy_android

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class DeliveryWindowTest {
    private fun stat(snapshot: Map<String, Any?>, key: String, field: String): Any? =
        (snapshot[key] as Map<*, *>)[field]

    @Test
    fun `one second channel backlog is visible despite regular BLE packets`() {
        var now = 0L
        val window = DeliveryWindow { now }
        now = 101_000_000L
        val first = window.notification(100_000_000L)
        now = 201_000_000L
        val second = window.notification(200_000_000L)
        now = 1_101_000_000L
        first(true)
        now = 1_201_000_000L
        second(true)
        window.stop()
        val result = window.snapshot()
        assertEquals(100.0, stat(result, "native_interval_ms", "mean"))
        assertEquals(1.0, stat(result, "main_dispatch_ms", "max"))
        assertEquals(1000.0, stat(result, "platform_channel_roundtrip_ms", "max"))
        assertEquals(1001.0, stat(result, "callback_to_flutter_reply_ms", "max"))
        assertEquals(0L, result["pending_replies_at_stop"])
    }

    @Test
    fun `late replies cannot change a stopped recording`() {
        var now = 100_000_000L
        val window = DeliveryWindow { now }
        val reply = window.notification(now)
        window.stop()
        val saved = window.snapshot()
        now += 3_000_000_000L
        reply(true)
        assertEquals(saved, window.snapshot())
        assertEquals(1L, saved["pending_replies_at_stop"])
    }

    @Test
    fun `failed or duplicate replies are not counted as successful delivery`() {
        var now = 0L
        val window = DeliveryWindow { now }
        val reply = window.notification(now)
        now += 1_000_000L
        reply(false)
        reply(true)
        val result = window.snapshot()
        assertEquals(1L, result["flutter_reply_count"])
        assertEquals(1L, result["flutter_reply_error_count"])
        assertEquals(0, stat(result, "platform_channel_roundtrip_ms", "count"))
    }

    @Test
    fun `capture is opt in bounded and separate from the next recording`() {
        var now = 0L
        val link = MeasurementLink({ true }, { now })
        val weight = ByteArray(17).also {
            byteArrayOf(0xA5.toByte(), 0x5A, 1, 1, 0, 9).copyInto(it)
        }
        assertNull(link.notification(weight, now))
        link.beginCapture()
        var oldReply: ((Boolean) -> Unit)? = null
        repeat(800) {
            now += 100_000_000L
            oldReply = link.notification(weight, now)
            if (it < 799) oldReply!!(true)
        }
        val first = link.endCapture()
        assertEquals(800L, first["weight_notification_count"])
        assertEquals(600, stat(first, "native_interval_ms", "count"))
        assertEquals(600, stat(first, "platform_channel_roundtrip_ms", "count"))
        assertEquals(1L, first["pending_replies_at_stop"])
        link.beginCapture()
        oldReply!!(true)
        assertEquals(0L, link.endCapture()["flutter_reply_count"])
    }
}
