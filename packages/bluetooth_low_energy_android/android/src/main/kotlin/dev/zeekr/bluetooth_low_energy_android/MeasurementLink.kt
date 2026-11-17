package dev.zeekr.bluetooth_low_energy_android

/** Reapplies the low-latency connection priority while measurement is subscribed. */
internal class MeasurementLink(private val requestPriority: (Boolean) -> Boolean) {
    private var streaming = false

    fun onResume() {
        if (streaming) setStreaming(true)
    }

    fun setStreaming(enabled: Boolean) {
        streaming = enabled
        // Connection tuning must never prevent a usable scale from connecting.
        try { requestPriority(enabled) } catch (_: Exception) { }
    }
}
