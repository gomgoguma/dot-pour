package dev.zeekr.bluetooth_low_energy_android

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.os.Build
import java.util.concurrent.Executor
import java.util.concurrent.ConcurrentHashMap

class MyBluetoothGattCallback(manager: MyCentralManager, executor: Executor) : BluetoothGattCallback() {
    private val mManager: MyCentralManager
    private val mExecutor: Executor
    private data class Notification(val characteristic: BluetoothGattCharacteristic, val value: ByteArray, val receivedAtNs: Long)
    private val pumps = ConcurrentHashMap<BluetoothGatt, NotificationPump<Notification>>()
    private val closedGatts = java.util.Collections.newSetFromMap(java.util.WeakHashMap<BluetoothGatt, Boolean>())
    private var shutDown = false
    private var capturePumps = emptyList<NotificationPump<Notification>>()
    private var captureStart = emptyList<Map<String, Any>>()
    private val measurementUUID = java.util.UUID.fromString("0000fff1-0000-1000-8000-00805f9b34fb")

    fun beginDeliveryCapture() {
        capturePumps = pumps.values.toList()
        captureStart = capturePumps.map { it.snapshot() }
    }
    fun endDeliveryCapture(): Map<String, Any> {
        val result = mapOf("at_start" to captureStart, "at_stop" to capturePumps.map { it.snapshot() })
        capturePumps = emptyList()
        captureStart = emptyList()
        return result
    }
    fun deliverySnapshot() = pumps.values.map { it.snapshot() }

    @Synchronized
    fun closeNotifications(gatt: BluetoothGatt) {
        closedGatts.add(gatt)
        pumps.remove(gatt)?.close()
    }
    @Synchronized
    fun closeAllNotifications() {
        closedGatts.addAll(pumps.keys)
        pumps.values.forEach { it.close() }
        pumps.clear()
    }
    @Synchronized
    fun shutdown() { shutDown = true; closeAllNotifications() }

    @Synchronized
    private fun notification(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
        if (shutDown || closedGatts.contains(gatt)) return
        val receivedAtNs = System.nanoTime()
        val snapshot = value.copyOf()
        val pump = pumps.getOrPut(gatt) {
            NotificationPump(mExecutor) { item: Notification, done ->
                mManager.onCharacteristicChanged(gatt, item.characteristic, item.value, item.receivedAtNs, done)
            }
        }
        pump.offer(Notification(characteristic, snapshot, receivedAtNs),
            characteristic.uuid == measurementUUID && DotWeightFrame.replaceable(snapshot))
    }

    init {
        mManager = manager
        mExecutor = executor
    }

    override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
        if (newState == android.bluetooth.BluetoothProfile.STATE_DISCONNECTED) closeNotifications(gatt)
        super.onConnectionStateChange(gatt, status, newState)
        mExecutor.execute {
            mManager.onConnectionStateChange(gatt, status, newState)
        }
    }

    override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
        super.onMtuChanged(gatt, mtu, status)
        mExecutor.execute {
            mManager.onMtuChanged(gatt, mtu, status)
        }
    }

    override fun onReadRemoteRssi(gatt: BluetoothGatt, rssi: Int, status: Int) {
        super.onReadRemoteRssi(gatt, rssi, status)
        mExecutor.execute {
            mManager.onReadRemoteRssi(gatt, rssi, status)
        }
    }

    override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
        super.onServicesDiscovered(gatt, status)
        mExecutor.execute {
            mManager.onServicesDiscovered(gatt, status)
        }
    }

    override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
        super.onCharacteristicRead(gatt, characteristic, value, status)
        mExecutor.execute {
            mManager.onCharacteristicRead(gatt, characteristic, status, value)
        }
    }

    // TODO: remove this override when minSdkVersion >= 33
    override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
        super.onCharacteristicRead(gatt, characteristic, status)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return
        }
        val value = characteristic.value
        mExecutor.execute {
            mManager.onCharacteristicRead(gatt, characteristic, status, value)
        }
    }

    override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
        super.onCharacteristicWrite(gatt, characteristic, status)
        mExecutor.execute {
            mManager.onCharacteristicWrite(gatt, characteristic, status)
        }
    }

    override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
        super.onCharacteristicChanged(gatt, characteristic, value)
        notification(gatt, characteristic, value)
    }

    // TODO: remove this override when minSdkVersion >= 33
    override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
        super.onCharacteristicChanged(gatt, characteristic)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return
        }
        notification(gatt, characteristic, characteristic.value)
    }

    override fun onDescriptorRead(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int, value: ByteArray) {
        super.onDescriptorRead(gatt, descriptor, status, value)
        mExecutor.execute {
            mManager.onDescriptorRead(gatt, descriptor, status, value)
        }
    }

    // TODO: remove this override when minSdkVersion >= 33
    override fun onDescriptorRead(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
        super.onDescriptorRead(gatt, descriptor, status)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return
        }
        val value = descriptor.value
        mExecutor.execute {
            mManager.onDescriptorRead(gatt, descriptor, status, value)
        }
    }

    override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
        super.onDescriptorWrite(gatt, descriptor, status)
        mExecutor.execute {
            mManager.onDescriptorWrite(gatt, descriptor, status)
        }
    }
}
