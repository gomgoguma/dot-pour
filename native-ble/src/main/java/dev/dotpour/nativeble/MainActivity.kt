package dev.dotpour.nativeble

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.Chronometer
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class MainActivity : Activity() {
    private val ink = Color.rgb(42, 35, 31)
    private val muted = Color.rgb(112, 97, 86)
    private val surfaceColor = Color.rgb(250, 246, 240)
    private val main = Handler(Looper.getMainLooper())
    private val latest = AtomicReference<Measurement?>()
    private val renderPending = AtomicBoolean()
    private lateinit var ble: DotBleClient
    private lateinit var root: LinearLayout
    private lateinit var heading: TextView
    private lateinit var status: TextView
    private lateinit var weight: TextView
    private lateinit var interval: TextView
    private lateinit var clock: Chronometer
    private lateinit var devices: LinearLayout
    private lateinit var scan: Button
    private lateinit var disconnect: Button
    private lateinit var tare: Button
    private lateinit var switchScreen: Button
    private var state = LinkState.IDLE
    private var openBrew = false

    private val renderFrame = Runnable {
        renderPending.set(false)
        if (!isDestroyed && !isFinishing) renderMeasurement()
    }
    private val freshnessCheck = object : Runnable {
        override fun run() {
            renderMeasurement()
            main.postDelayed(this, 250)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = surfaceColor
        window.navigationBarColor = surfaceColor
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR

        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(28), dp(24), dp(24))
        }
        val scroll = ScrollView(this).apply {
            isFillViewport = true
            setBackgroundColor(surfaceColor)
            addView(root)
            @Suppress("DEPRECATION")
            setOnApplyWindowInsetsListener { view, insets ->
                view.setPadding(
                    insets.systemWindowInsetLeft,
                    insets.systemWindowInsetTop,
                    insets.systemWindowInsetRight,
                    insets.systemWindowInsetBottom,
                )
                insets
            }
        }
        setContentView(scroll)

        root.addView(text("Dot Pour Native B", 16, muted))
        heading = text("계량", 28).apply { typeface = Typeface.DEFAULT_BOLD }
        add(heading, 8)
        status = text("저울을 검색해 연결하세요.", 15, muted)
        add(status, 8)

        weight = text("— g", 62).apply {
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
        }
        add(weight, 20)
        interval = text("GATT 수신 대기", 14, muted)
        add(interval, 4)

        clock = Chronometer(this).apply {
            textSize = 22f
            setTextColor(ink)
            gravity = Gravity.CENTER
            visibility = View.GONE
        }
        add(clock, 14)
        switchScreen = button("추출 화면", 18) { showBrew(!openBrew) }
        tare = button("영점", 10) { ble.tare() }
        scan = button("DOT 검색", 16) { scanWithPermission() }
        disconnect = button("연결 해제", 0) { ble.disconnect() }
        devices = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        add(devices, 10)

        ble = DotBleClient(
            applicationContext,
            { link, message -> main.post { if (!isDestroyed) updateStatus(link, message) } },
            { found -> main.post { if (!isDestroyed) showDevices(found) } },
            { sample ->
                latest.set(sample)
                if (renderPending.compareAndSet(false, true)) main.post { root.postOnAnimation(renderFrame) }
            },
        )
        updateStatus(LinkState.IDLE, "저울을 검색해 연결하세요.")
    }

    private fun text(value: String, size: Int, color: Int = ink) =
        TextView(this).apply {
            text = value
            textSize = size.toFloat()
            setTextColor(color)
            gravity = Gravity.CENTER
        }

    private fun add(view: View, spacing: Int) {
        root.addView(view, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(spacing) })
    }

    private fun button(title: String, margin: Int, action: () -> Unit): Button =
        Button(this).apply {
            text = title
            setAllCaps(false)
            setOnClickListener { action() }
            add(this, margin)
        }

    private fun dp(value: Int): Int =
        (resources.displayMetrics.density * value).toInt()

    private fun scanWithPermission() {
        val required = if (Build.VERSION.SDK_INT >= 31) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        if (required.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }) {
            ble.startScan()
        } else requestPermissions(required, 1)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, results)
        if (requestCode != 1) return
        if (results.isNotEmpty() && results.all { it == PackageManager.PERMISSION_GRANTED }) {
            ble.startScan()
        } else status.text = "DOT를 검색하려면 블루투스 권한을 허용해 주세요."
    }

    private fun updateStatus(newState: LinkState, message: String) {
        state = newState
        status.text = message
        val ready = state == LinkState.READY
        scan.isEnabled = state == LinkState.IDLE
        tare.isEnabled = ready
        switchScreen.isEnabled = ready
        disconnect.isEnabled = state != LinkState.IDLE
        devices.visibility = if (state == LinkState.CONNECTING || ready) View.GONE else View.VISIBLE
        if (!ready) {
            latest.set(null)
            if (openBrew) showBrew(false)
        }
        renderMeasurement()
    }

    private fun showDevices(found: List<DotDevice>) {
        devices.removeAllViews()
        found.forEach { device ->
            devices.addView(Button(this).apply {
                text = "연결 · ${device.name}"
                setAllCaps(false)
                setOnClickListener { ble.connect(device) }
            })
        }
    }

    private fun showBrew(show: Boolean) {
        openBrew = show
        heading.text = if (show) "추출" else "계량"
        clock.visibility = if (show) View.VISIBLE else View.GONE
        switchScreen.text = if (show) "계량으로 돌아가기" else "추출 화면"
        if (show) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            ble.tare()
            clock.base = SystemClock.elapsedRealtime()
            clock.start()
        } else {
            clock.stop()
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        renderMeasurement()
    }

    private fun renderMeasurement() {
        val sample = latest.get()?.takeIf { SystemClock.elapsedRealtime() - it.receivedAt < 2_000 }
        val reading = when {
            sample == null -> "— g"
            sample.overloaded -> "용량 초과"
            else -> String.format(Locale.getDefault(), "%.1f g", sample.grams)
        }
        val timing = sample?.intervalMs?.let { "최근 GATT 수신 간격 $it ms" } ?: "GATT 수신 대기"
        if (weight.text != reading) weight.text = reading
        if (interval.text != timing) interval.text = timing
    }

    override fun onResume() {
        super.onResume()
        ble.resume()
        main.removeCallbacks(freshnessCheck)
        freshnessCheck.run()
    }

    override fun onPause() {
        main.removeCallbacks(freshnessCheck)
        super.onPause()
    }

    @Deprecated("Handles the comparison app's two screens")
    override fun onBackPressed() {
        if (openBrew) showBrew(false) else super.onBackPressed()
    }

    override fun onDestroy() {
        main.removeCallbacks(freshnessCheck)
        root.removeCallbacks(renderFrame)
        ble.close()
        super.onDestroy()
    }
}
