package dev.dotpour.nativeble

import java.nio.ByteBuffer
import java.util.UUID

internal object DotProtocol {
    val service: UUID = dotUuid("fff0")
    val notify: UUID = dotUuid("fff1")
    val write: UUID = dotUuid("fff2")
    val cccd: UUID = dotUuid("2902")
    const val GRAMS = 0x06
    const val STANDARD_MODE = 0x08
    const val TARE = 0x0d

    private fun dotUuid(short: String): UUID =
        UUID.fromString("0000$short-0000-1000-8000-00805f9b34fb")

    fun writeCommand(command: Int, vararg data: Int): ByteArray {
        val frame = ByteBuffer.allocate(8 + data.size)
        frame.put(0xa5.toByte()).put(0x5a.toByte()).put(3.toByte()).put(command.toByte())
        frame.putShort(data.size.toShort())
        data.forEach { frame.put(it.toByte()) }
        val bytes = frame.array()
        frame.putShort(crc16(bytes, 0, bytes.size - 2).toShort())
        return bytes
    }

    data class Frame(val opcode: Int, val command: Int, val payload: ByteArray) {
        val accepted: Boolean get() = opcode == 3 && payload.size == 1 && payload[0] == 1.toByte()

        fun weight(): Double? =
            if (opcode == 1 && command == 1 && payload.size == 9 && payload[8] == 0.toByte()) {
                ByteBuffer.wrap(payload).int / 10.0
            } else null

        val overloaded: Boolean
            get() = opcode == 1 && command == 1 && payload.size == 9 && payload[8] != 0.toByte()
    }

    class Decoder {
        private var pending = byteArrayOf()

        fun clear() {
            pending = byteArrayOf()
        }

        fun add(chunk: ByteArray, onFrame: (Frame) -> Unit) {
            val bytes = pending + chunk
            var index = 0
            while (bytes.size - index >= 2) {
                if (bytes[index].toInt() and 0xff != 0xa5 || bytes[index + 1] != 0x5a.toByte()) {
                    index++
                    continue
                }
                if (bytes.size - index < 6) break

                val opcode = bytes[index + 2].toInt() and 0xff
                val length = unsignedShort(bytes, index + 4)
                if (opcode !in 1..3 || length > 128) {
                    index++
                    continue
                }
                val end = index + length + 8
                if (end > bytes.size) break

                val expected = unsignedShort(bytes, end - 2)
                if (expected != 0 && expected != crc16(bytes, index, end - 2)) {
                    index++
                    continue
                }
                val command = bytes[index + 3].toInt() and 0xff
                onFrame(Frame(opcode, command, bytes.copyOfRange(index + 6, end - 2)))
                index = end
            }
            pending = bytes.copyOfRange(index, bytes.size)
        }
    }

    private fun unsignedShort(bytes: ByteArray, index: Int): Int =
        ((bytes[index].toInt() and 0xff) shl 8) or (bytes[index + 1].toInt() and 0xff)

    private fun crc16(bytes: ByteArray, from: Int, until: Int): Int {
        var crc = 0xffff
        for (index in from until until) {
            crc = crc xor (bytes[index].toInt() and 0xff)
            repeat(8) {
                crc = if (crc and 1 != 0) (crc ushr 1) xor 0xa001 else crc ushr 1
            }
        }
        return crc
    }
}
