package dev.zeekr.bluetooth_low_energy_android

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class MeasurementLinkTest {
    private fun weight() = ByteArray(17).also {
        byteArrayOf(0xA5.toByte(), 0x5A, 1, 1, 0, 9).copyInto(it)
    }

    @Test
    fun `streaming requests high priority then releases it`() {
        val requests = mutableListOf<Boolean>()
        val link = MeasurementLink({ requests.add(it); true })
        link.setStreaming(true)
        assertEquals("high", link.snapshot()["requested_priority"])
        assertEquals(true, link.snapshot()["priority_request_accepted"])
        link.setStreaming(false)
        assertEquals(listOf(true, false), requests)
        assertEquals("balanced", link.snapshot()["requested_priority"])
    }

    @Test
    fun `a rejected priority request does not prevent measurement delivery`() {
        val link = MeasurementLink({ false }, { 105_000_000L })
        link.setStreaming(true)
        link.notification(weight(), 100_000_000L)
        assertEquals(false, link.snapshot()["priority_request_accepted"])
        assertEquals(1L, link.snapshot()["weight_notification_count"])
    }

    @Test
    fun `permission or platform errors are nonfatal`() {
        val link = MeasurementLink({ throw SecurityException("permission") }, { 0L })
        assertDoesNotThrow { link.setStreaming(true) }
        assertEquals(false, link.snapshot()["priority_request_accepted"])
        assertDoesNotThrow { link.setStreaming(false) }
    }

    @Test
    fun `native receipt interval is independent of main executor backlog`() {
        var now = 105_000_000L
        val link = MeasurementLink({ true }, { now })
        link.notification(weight(), 100_000_000L)
        now = 920_000_000L
        link.notification(weight(), 200_000_000L)
        val snapshot = link.snapshot()
        assertEquals(100.0, snapshot["native_interval_mean_ms"])
        assertEquals(720.0, snapshot["main_dispatch_max_ms"])
        assertEquals(720.0, snapshot["last_notification_age_ms"])
    }

    @Test
    fun `slow native delivery can be distinguished from dispatch delay`() {
        var now = 101_000_000L
        val link = MeasurementLink({ true }, { now })
        link.notification(weight(), 100_000_000L)
        now = 1_101_000_000L
        link.notification(weight(), 1_100_000_000L)
        assertEquals(1000.0, link.snapshot()["native_interval_mean_ms"])
        assertEquals(1.0, link.snapshot()["main_dispatch_max_ms"])
    }

    @Test
    fun `acknowledgements and fragmented frames do not skew weight timing`() {
        val link = MeasurementLink({ true }, { 0L })
        link.notification(byteArrayOf(0xA5.toByte(), 0x5A, 3, 13, 0, 1, 1, 0, 0), 0L)
        link.notification(weight().copyOf(8), 0L)
        assertEquals(0L, link.snapshot()["weight_notification_count"])
        assertNull(link.snapshot()["native_interval_mean_ms"])
    }

    @Test
    fun `statistics are bounded and a new connection starts empty`() {
        var now = 0L
        val link = MeasurementLink({ true }, { now })
        repeat(200) {
            now += 100_000_000L
            link.notification(weight(), now)
        }
        assertEquals(64, link.snapshot()["window_size"])
        assertEquals(200L, link.snapshot()["weight_notification_count"])
        assertEquals(100.0, link.snapshot()["native_interval_mean_ms"])
        val reconnect = MeasurementLink({ true }, { now })
        assertEquals(0L, reconnect.snapshot()["weight_notification_count"])
        assertNull(reconnect.snapshot()["last_notification_age_ms"])
    }
}
