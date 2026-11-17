package dev.zeekr.bluetooth_low_energy_android

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class MeasurementLinkTest {
    @Test
    fun `resume reapplies priority only for subscribed measurement links`() {
        val requests = mutableListOf<Boolean>()
        val link = MeasurementLink({ requests.add(it); true })
        link.onResume()
        assertEquals(emptyList<Boolean>(), requests)
        link.setStreaming(true)
        repeat(5) { link.onResume() }
        assertEquals(6, requests.count { it })
        link.setStreaming(false)
        link.onResume()
        assertEquals(listOf(true, true, true, true, true, true, false), requests)
    }

    @Test
    fun `a rejected priority request is retried on resume`() {
        val requests = mutableListOf<Boolean>()
        val link = MeasurementLink({ requests.add(it); false })
        link.setStreaming(true)
        link.onResume()
        assertEquals(listOf(true, true), requests)
    }

    @Test
    fun `permission or platform errors are nonfatal`() {
        val link = MeasurementLink({ throw SecurityException("permission") })
        assertDoesNotThrow { link.setStreaming(true) }
        assertDoesNotThrow { link.onResume() }
        assertDoesNotThrow { link.setStreaming(false) }
    }
}
