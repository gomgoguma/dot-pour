package dev.zeekr.bluetooth_low_energy_android

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

abstract class MyBluetoothLowEnergyManager(val context: Context) {
    companion object {
        const val AUTHORIZE_CODE = 0x00
    }

    private val mBroadcastReceiver: BroadcastReceiver by lazy { MyBroadcastReceiver(this) }
    private val mRequestPermissionsResultListener: PluginRegistry.RequestPermissionsResultListener by lazy { MyRequestPermissionResultListener(this) }

    private var mBinding: ActivityPluginBinding? = null
    private var disposed = false

    init {
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        filter.addAction(BluetoothAdapter.ACTION_LOCAL_NAME_CHANGED)
        context.registerReceiver(mBroadcastReceiver, filter)
    }

    val activity: Activity get() = checkNotNull(mBinding).activity

    fun onAttachedToActivity(binding: ActivityPluginBinding) {
        mBinding?.removeRequestPermissionsResultListener(mRequestPermissionsResultListener)
        binding.addRequestPermissionsResultListener(mRequestPermissionsResultListener)
        mBinding = binding
    }

    fun onDetachedFromActivity() {
        mBinding?.removeRequestPermissionsResultListener(mRequestPermissionsResultListener)
        mBinding = null
    }

    open fun dispose() {
        if (disposed) return
        disposed = true
        onDetachedFromActivity()
        context.unregisterReceiver(mBroadcastReceiver)
    }

    abstract fun onReceive(context: Context, intent: Intent)
    abstract fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, results: IntArray): Boolean
}
