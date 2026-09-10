package gov.doca.themis.themis_app

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Exposes device RAM so the Flutter UI can auto-pick a glass quality
        // tier (Premium / Balanced / Lite). No extra plugin dependency.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gov.doca.themis/perf",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getMemoryInfo") {
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val info = ActivityManager.MemoryInfo()
                    am.getMemoryInfo(info)
                    result.success(
                        mapOf(
                            "totalMemMb" to (info.totalMem / (1024 * 1024)),
                            "lowRamDevice" to am.isLowRamDevice,
                        ),
                    )
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
