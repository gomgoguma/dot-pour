package dev.zeekr.bluetooth_low_energy_android

import java.util.ArrayDeque
import java.util.concurrent.Executor
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class NotificationPumpTest {
    private class MainQueue : Executor {
        val tasks = ArrayDeque<Runnable>()
        override fun execute(command: Runnable) { tasks.addLast(command) }
        fun run() { while (tasks.isNotEmpty()) tasks.removeFirst().run() }
    }

    @Test
    fun `blocked main executor keeps latest weight and only one scheduled task`() {
        val main = MainQueue()
        val sent = mutableListOf<Int>()
        val pump = NotificationPump<Int>(main) { value, done -> sent.add(value); done(true) }
        repeat(1000) { pump.offer(it, true) }
        assertEquals(1, main.tasks.size)
        assertEquals(1, pump.snapshot()["queued"])
        main.run()
        assertEquals(listOf(999), sent)
        assertEquals(999L, pump.snapshot()["weights_coalesced"])
    }

    @Test
    fun `blocked Dart handler has only one in flight plus the newest pending weight`() {
        val main = MainQueue()
        val sent = mutableListOf<Int>()
        val replies = ArrayDeque<(Boolean) -> Unit>()
        val pump = NotificationPump<Int>(main) { value, done -> sent.add(value); replies.addLast(done) }
        pump.offer(1, true)
        main.run()
        for (i in 2..1000) { pump.offer(i, true); main.run() }
        assertEquals(listOf(1), sent)
        assertEquals(1, pump.snapshot()["queued"])
        replies.removeFirst()(true)
        main.run()
        assertEquals(listOf(1, 1000), sent)
        replies.removeFirst()(true)
        assertEquals(false, pump.snapshot()["in_flight"])
    }

    @Test
    fun `ack and fragment barriers preserve stream order around coalesced weights`() {
        val main = MainQueue()
        val sent = mutableListOf<String>()
        val pump = NotificationPump<String>(main) { value, done -> sent.add(value); done(true) }
        pump.offer("old weight", true)
        pump.offer("last before ACK", true)
        pump.offer("tare ACK", false)
        pump.offer("new zero", true)
        pump.offer("fragment A", false)
        pump.offer("fragment B", false)
        pump.offer("old tail", true)
        pump.offer("latest", true)
        main.run()
        assertEquals(listOf("last before ACK", "tare ACK", "new zero", "fragment A", "fragment B", "latest"), sent)
    }

    @Test
    fun `close drops queued work and late replies cannot restart an old connection`() {
        val main = MainQueue()
        val sent = mutableListOf<Int>()
        lateinit var reply: (Boolean) -> Unit
        val pump = NotificationPump<Int>(main) { value, done -> sent.add(value); reply = done }
        pump.offer(1, true)
        main.run()
        pump.offer(2, true)
        pump.close()
        pump.offer(3, true)
        reply(true)
        reply(true)
        main.run()
        assertEquals(listOf(1), sent)
        assertEquals(0, pump.snapshot()["queued"])
        assertEquals(1L, pump.snapshot()["discarded_on_close"])
    }

    @Test
    fun `failed delivery does not deadlock future measurements`() {
        val main = MainQueue()
        val sent = mutableListOf<Int>()
        val pump = NotificationPump<Int>(main) { value, done ->
            sent.add(value)
            if (value == 1) throw IllegalStateException("closed channel")
            done(true)
        }
        pump.offer(1, false)
        pump.offer(2, true)
        main.run()
        assertEquals(listOf(1, 2), sent)
        assertEquals(1L, pump.snapshot()["delivery_errors"])
    }

    @Test
    fun `overload bad CRC incomplete and non weight frames cannot be replaced`() {
        val weight = byteArrayOf(0xA5.toByte(), 0x5A, 1, 1, 0, 9, 0, 0, 0, 123, 0, 0, 0, 0, 0, 0, 0)
        assertTrue(DotWeightFrame.replaceable(weight))
        assertFalse(DotWeightFrame.replaceable(weight.copyOf(8)))
        assertFalse(DotWeightFrame.replaceable(weight + weight))
        assertFalse(DotWeightFrame.replaceable(weight.copyOf().also { it[14] = 1 }))
        assertFalse(DotWeightFrame.replaceable(weight.copyOf().also { it[2] = 3 }))
        assertFalse(DotWeightFrame.replaceable(weight.copyOf().also { it[16] = 1 }))
        // Fixed complete packet, including its nonzero wire CRC.
        val crcFrame = byteArrayOf(0xA5.toByte(), 0x5A, 1, 1, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xF3.toByte(), 0x50.toByte())
        assertTrue(DotWeightFrame.replaceable(crcFrame))
    }
}
