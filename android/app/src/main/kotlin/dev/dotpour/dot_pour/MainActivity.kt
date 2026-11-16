package dev.dotpour.dot_pour

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private data class PendingExport(val content: String, val result: MethodChannel.Result)
    private var pendingExport: PendingExport? = null
    private var exportChannel: MethodChannel? = null
    private val saveRequest = 0x4450

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        exportChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "dot_pour/diagnostic_export"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "save") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingExport != null) {
                    result.error("busy", "파일 저장이 진행 중입니다.", null)
                    return@setMethodCallHandler
                }
                val content = call.argument<String>("content")
                val fileName = call.argument<String>("fileName")
                if (content == null || fileName == null ||
                    !fileName.matches(Regex("[A-Za-z0-9._-]+\\.json"))) {
                    result.error("invalid_export", "저장할 진단 파일이 올바르지 않습니다.", null)
                    return@setMethodCallHandler
                }
                pendingExport = PendingExport(content, result)
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    }
                    startActivityForResult(intent, saveRequest)
                } catch (_: Exception) {
                    pendingExport = null
                    result.error("picker_unavailable", "파일 저장 창을 열지 못했습니다.", null)
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != saveRequest) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val export = pendingExport ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pendingExport = null
            export.result.success(false)
            return
        }
        // Document providers can be slow. Do not block BLE callbacks or UI.
        Thread {
            val succeeded = try {
                val output = contentResolver.openOutputStream(uri, "wt")
                    ?: throw IllegalStateException("No output stream")
                output.use { it.write(export.content.toByteArray(Charsets.UTF_8)) }
                true
            } catch (_: Exception) {
                false
            }
            runOnUiThread {
                if (pendingExport === export) {
                    pendingExport = null
                    if (succeeded) export.result.success(true)
                    else export.result.error("write_failed", "진단 파일을 저장하지 못했습니다.", null)
                }
            }
        }.start()
    }

    override fun onDestroy() {
        pendingExport?.result?.error("activity_closed", "파일 저장이 취소되었습니다.", null)
        pendingExport = null
        exportChannel?.setMethodCallHandler(null)
        exportChannel = null
        super.onDestroy()
    }
}
