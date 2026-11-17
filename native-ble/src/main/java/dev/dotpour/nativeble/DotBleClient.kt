package dev.dotpour.nativeble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock

internal data class DotDevice(val device: BluetoothDevice, val name: String)
internal data class Measurement(
    val grams: Double?,
    val overloaded: Boolean,
    val receivedAt: Long,
    val intervalMs: Long?,
)

internal enum class LinkState { IDLE, SCANNING, CONNECTING, READY }

@SuppressLint("MissingPermission")
internal class DotBleClient(
    private val context: Context,
    private val onStatus: (LinkState, String) -> Unit,
    private val onDevices: (List<DotDevice>) -> Unit,
    private val onMeasurement: (Measurement) -> Unit,
) {
    private enum class Step { IDLE, CONNECTING, DISCOVERY, MTU, SUBSCRIBE, GRAMS, MODE, READY }

    private val thread = HandlerThread("DOT GATT").apply { start() }
    private val handler = Handler(thread.looper)
    private val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter
    private val devices = linkedMapOf<String, DotDevice>()
    private val decoder = DotProtocol.Decoder()
    private var scan: ScanCallback? = null
    private var gatt: BluetoothGatt? = null
    private var write: BluetoothGattCharacteristic? = null
    private var notify: BluetoothGattCharacteristic? = null
    private var step = Step.IDLE
    private var gramsWritten = false
    private var gramsAcknowledged = false
    private var tarePending = false
    private var lastReceipt: Long? = null
    private val linkTimeout = Runnable { endLink("저울 연결 응답이 지연됐습니다. 다시 연결해 주세요.") }
    private val tareTimeout = Runnable { finishTare("영점 응답이 지연됐습니다.") }

    fun startScan() {
        handler.post {
            if (gatt != null || scan != null) return@post
            val scanner = adapter?.bluetoothLeScanner
            if (scanner == null) {
                onStatus(LinkState.IDLE, "블루투스를 켜고 다시 검색해 주세요.")
                return@post
            }
            devices.clear()
            onDevices(emptyList())
            val callback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    handler.post { if (scan === this) discover(result) }
                }

                override fun onScanFailed(errorCode: Int) {
                    handler.post {
                        if (scan === this) {
                            stopScan()
                            onStatus(LinkState.IDLE, "저울 검색 실패 ($errorCode)")
                        }
                    }
                }
            }
            scan = callback
            try {
                scanner.startScan(
                    null,
                    ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),
                    callback,
                )
            } catch (_: SecurityException) {
                scan = null
                onStatus(LinkState.IDLE, "근처 기기 권한을 허용해 주세요.")
                return@post
            }
            onStatus(LinkState.SCANNING, "DOT 검색 중…")
            handler.postDelayed({
                if (scan === callback) {
                    stopScan()
                    val message = if (devices.isEmpty()) "DOT를 찾지 못했습니다." else "연결할 DOT를 선택하세요."
                    onStatus(LinkState.IDLE, message)
                }
            }, 12_000)
        }
    }

    private fun discover(result: ScanResult) {
        val record = result.scanRecord ?: return
        val name = record.deviceName.orEmpty()
        if (!name.contains("dot", ignoreCase = true) && !name.contains("tes017", ignoreCase = true) &&
            record.serviceUuids?.none { it.uuid == DotProtocol.service } != false
        ) return
        val device = result.device
        if (devices.containsKey(device.address)) return
        devices[device.address] = DotDevice(device, name.ifBlank { "TIMEMORE DOT" })
        onDevices(devices.values.toList())
    }

    private fun stopScan() {
        val active = scan ?: return
        scan = null
        try { adapter?.bluetoothLeScanner?.stopScan(active) } catch (_: SecurityException) { }
    }

    fun connect(device: DotDevice) {
        handler.post {
            if (gatt != null) return@post
            stopScan()
            step = Step.CONNECTING
            onStatus(LinkState.CONNECTING, "${device.name} 연결 중…")
            gatt = try {
                device.device.connectGatt(
                    context, false, callbacks, BluetoothDevice.TRANSPORT_LE,
                    BluetoothDevice.PHY_LE_1M_MASK, handler,
                )
            } catch (_: SecurityException) { null }
            if (gatt == null) {
                endLink("저울 연결을 시작하지 못했습니다.")
            } else {
                handler.postDelayed(linkTimeout, 18_000)
            }
        }
    }

    fun resume() {
        handler.post { if (step == Step.READY) gatt?.let(::requestPriority) }
    }

    fun disconnect() {
        handler.post {
            stopScan()
            endLink("연결 해제됨")
        }
    }

    fun close() {
        handler.post {
            stopScan()
            endLink("연결 해제됨")
            thread.quitSafely()
        }
    }

    fun tare() {
        handler.post {
            if (step != Step.READY || tarePending) return@post
            val current = gatt ?: return@post
            tarePending = send(current, DotProtocol.TARE)
            if (tarePending) handler.postDelayed(tareTimeout, 4_000)
            else onStatus(LinkState.READY, "영점 명령을 보내지 못했습니다.")
        }
    }

    private val callbacks = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(connection: BluetoothGatt, status: Int, state: Int) {
            if (gatt !== connection) return
            if (state == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) {
                endLink("저울 연결이 종료됐습니다 ($status).")
            } else if (state == BluetoothProfile.STATE_CONNECTED && step == Step.CONNECTING) {
                step = Step.DISCOVERY
                if (!connection.discoverServices()) endLink("DOT 서비스를 검색하지 못했습니다.")
            }
        }

        override fun onServicesDiscovered(connection: BluetoothGatt, status: Int) {
            if (gatt !== connection || step != Step.DISCOVERY) return
            val service = connection.getService(DotProtocol.service)
            write = service?.getCharacteristic(DotProtocol.write)
            notify = service?.getCharacteristic(DotProtocol.notify)
            if (status != BluetoothGatt.GATT_SUCCESS || write == null || notify == null) {
                endLink("DOT의 FFF0 BLE 서비스를 찾지 못했습니다.")
                return
            }
            step = Step.MTU
            if (connection.requestMtu(247)) {
                handler.postDelayed({
                    if (gatt === connection && step == Step.MTU) subscribe(connection)
                }, 3_000)
            } else {
                subscribe(connection)
            }
        }

        override fun onMtuChanged(connection: BluetoothGatt, mtu: Int, status: Int) {
            if (gatt === connection && step == Step.MTU) subscribe(connection)
        }

        override fun onDescriptorWrite(connection: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            if (gatt !== connection || step != Step.SUBSCRIBE || descriptor.uuid != DotProtocol.cccd) return
            step = Step.GRAMS
            if (status != BluetoothGatt.GATT_SUCCESS || !send(connection, DotProtocol.GRAMS, 0)) {
                endLink("무게 알림 또는 g 단위를 설정하지 못했습니다.")
            }
        }

        override fun onCharacteristicWrite(connection: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (gatt !== connection || characteristic.uuid != DotProtocol.write) return
            when (step) {
                Step.GRAMS -> if (status == BluetoothGatt.GATT_SUCCESS) {
                    gramsWritten = true
                    maybeSelectStandardMode(connection)
                } else endLink("g 단위 설정에 실패했습니다.")
                Step.MODE -> ready()
                Step.READY -> if (tarePending && status != BluetoothGatt.GATT_SUCCESS) finishTare("영점 명령 전송 실패")
                else -> Unit
            }
        }

        override fun onCharacteristicChanged(connection: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            if (characteristic.uuid == DotProtocol.notify) receive(connection, value)
        }

        @Deprecated("Used on Android 12 and older")
        override fun onCharacteristicChanged(connection: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            if (Build.VERSION.SDK_INT < 33 && characteristic.uuid == DotProtocol.notify) {
                characteristic.value?.let { receive(connection, it) }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun subscribe(connection: BluetoothGatt) {
        val characteristic = notify ?: return
        val descriptor = characteristic.getDescriptor(DotProtocol.cccd)
        if (descriptor == null || !connection.setCharacteristicNotification(characteristic, true)) {
            endLink("DOT 무게 알림을 켜지 못했습니다.")
            return
        }
        step = Step.SUBSCRIBE
        requestPriority(connection)
        val value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        val sent = if (Build.VERSION.SDK_INT >= 33) {
            connection.writeDescriptor(descriptor, value) == BluetoothStatusCodes.SUCCESS
        } else {
            descriptor.value = value
            connection.writeDescriptor(descriptor)
        }
        if (!sent) endLink("DOT 알림 설정을 전송하지 못했습니다.")
    }

    private fun requestPriority(connection: BluetoothGatt) {
        try { connection.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH) }
        catch (_: SecurityException) { }
    }

    @Suppress("DEPRECATION")
    private fun send(connection: BluetoothGatt, command: Int, vararg data: Int): Boolean {
        val characteristic = write ?: return false
        val frame = DotProtocol.writeCommand(command, *data)
        val type = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        return try {
            if (Build.VERSION.SDK_INT >= 33) {
                connection.writeCharacteristic(characteristic, frame, type) == BluetoothStatusCodes.SUCCESS
            } else {
                characteristic.writeType = type
                characteristic.value = frame
                connection.writeCharacteristic(characteristic)
            }
        } catch (_: SecurityException) { false }
    }

    private fun maybeSelectStandardMode(connection: BluetoothGatt) {
        if (step != Step.GRAMS || !gramsWritten || !gramsAcknowledged) return
        step = Step.MODE
        if (send(connection, DotProtocol.STANDARD_MODE, 0x01, 0x00)) {
            handler.postDelayed({
                if (gatt === connection && step == Step.MODE) ready()
            }, 2_000)
        } else ready()
    }

    private fun receive(connection: BluetoothGatt, value: ByteArray) {
        if (gatt !== connection) return
        val receivedAt = SystemClock.elapsedRealtime()
        decoder.add(value) { frame ->
            if (gatt !== connection) return@add
            if (frame.opcode == 3 && frame.command == DotProtocol.GRAMS && step == Step.GRAMS) {
                if (frame.accepted) {
                    gramsAcknowledged = true
                    maybeSelectStandardMode(connection)
                } else endLink("저울이 g 단위 설정을 거부했습니다.")
            }
            if (frame.opcode == 3 && frame.command == DotProtocol.TARE && tarePending) {
                finishTare(if (frame.accepted) "DOT 연결됨" else "저울이 영점 명령을 거부했습니다.")
            }
            if (step == Step.READY) {
                val grams = frame.weight()
                if (grams != null || frame.overloaded) {
                    val interval = lastReceipt?.let { receivedAt - it }
                    lastReceipt = receivedAt
                    onMeasurement(Measurement(grams, frame.overloaded, receivedAt, interval))
                }
            }
        }
    }

    private fun ready() {
        step = Step.READY
        handler.removeCallbacks(linkTimeout)
        onStatus(LinkState.READY, "DOT 연결됨")
    }

    private fun finishTare(message: String) {
        tarePending = false
        handler.removeCallbacks(tareTimeout)
        onStatus(LinkState.READY, message)
    }

    private fun endLink(message: String) {
        handler.removeCallbacks(linkTimeout)
        handler.removeCallbacks(tareTimeout)
        val previous = gatt
        gatt = null
        step = Step.IDLE
        write = null
        notify = null
        gramsWritten = false
        gramsAcknowledged = false
        tarePending = false
        lastReceipt = null
        decoder.clear()
        if (previous != null) {
            try { previous.disconnect() } catch (_: SecurityException) { }
            try { previous.close() } catch (_: SecurityException) { }
        }
        onStatus(LinkState.IDLE, message)
    }
}
