package dev.zeekr.bluetooth_low_energy_android

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.mockito.Mockito.*

class ManagerLifecycleTest {
    @Suppress("UNCHECKED_CAST")
    private fun connections(manager: MyCentralManager): MutableMap<String, BluetoothGatt> {
        val field = MyCentralManager::class.java.getDeclaredField("mGATTs")
        field.isAccessible = true
        return field.get(manager) as MutableMap<String, BluetoothGatt>
    }

    @Test
    fun `engine disposal releases all native clients even if one disconnect fails`() {
        val context = mock(Context::class.java)
        val manager = MyCentralManager(context, mock(BinaryMessenger::class.java))
        val first = mock(BluetoothGatt::class.java)
        val second = mock(BluetoothGatt::class.java)
        connections(manager)["first"] = first
        connections(manager)["second"] = second
        doThrow(SecurityException("permission revoked")).`when`(first).disconnect()
        manager.dispose()
        manager.dispose()
        verify(first, times(1)).disconnect()
        verify(first, times(1)).close()
        verify(second, times(1)).disconnect()
        verify(second, times(1)).close()
        verify(context, times(1)).unregisterReceiver(any(BroadcastReceiver::class.java))
        assertTrue(connections(manager).isEmpty())
    }

    @Test
    fun `late disconnect from the old GATT cannot remove a replacement connection`() {
        val context = mock(Context::class.java)
        val manager = MyCentralManager(context, mock(BinaryMessenger::class.java))
        val device = mock(BluetoothDevice::class.java)
        `when`(device.address).thenReturn("test-device")
        val old = mock(BluetoothGatt::class.java)
        `when`(old.device).thenReturn(device)
        val replacement = mock(BluetoothGatt::class.java)
        connections(manager)["test-device"] = replacement
        manager.onConnectionStateChange(old, 0, BluetoothProfile.STATE_DISCONNECTED)
        assertSame(replacement, connections(manager)["test-device"])
        verify(old).close()
        verify(replacement, never()).close()
        manager.dispose()
    }
}
