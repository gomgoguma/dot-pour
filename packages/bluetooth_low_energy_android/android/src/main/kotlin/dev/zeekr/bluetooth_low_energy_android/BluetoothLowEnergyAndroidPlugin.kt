package dev.zeekr.bluetooth_low_energy_android

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

/** BluetoothLowEnergyAndroidPlugin */
class BluetoothLowEnergyAndroidPlugin : FlutterPlugin, ActivityAware {
    private lateinit var mCentralManager: MyCentralManager
    private lateinit var mPeripheralManager: MyPeripheralManager
    private var measurementChannel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        val binaryMessenger = binding.binaryMessenger
        mCentralManager = MyCentralManager(context, binaryMessenger)
        mPeripheralManager = MyPeripheralManager(context, binaryMessenger)
        MyCentralManagerHostAPI.setUp(binaryMessenger, mCentralManager)
        MyPeripheralManagerHostAPI.setUp(binaryMessenger, mPeripheralManager)
        measurementChannel = MethodChannel(binaryMessenger, "dot_pour/ble_control").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "resume" -> { mCentralManager.resumeMeasurementLinks(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        mCentralManager.dispose()
        mPeripheralManager.dispose()
        val binaryMessenger = binding.binaryMessenger
        MyCentralManagerHostAPI.setUp(binaryMessenger, null)
        MyPeripheralManagerHostAPI.setUp(binaryMessenger, null)
        measurementChannel?.setMethodCallHandler(null)
        measurementChannel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        mCentralManager.onAttachedToActivity(binding)
        mPeripheralManager.onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        mCentralManager.onDetachedFromActivity()
        mPeripheralManager.onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }
}
