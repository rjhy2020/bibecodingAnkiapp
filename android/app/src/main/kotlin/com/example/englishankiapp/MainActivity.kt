package com.example.englishankiapp

import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "anki_provider"
    private val ankiPermission = "com.ichi2.anki.permission.READ_WRITE_DATABASE"
    private val ankiPermissionRequestCode = 41010
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val client = AnkiProviderClient(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "getStatus" -> {
                        ioExecutor.execute {
                            val status = client.getStatus()
                            runOnUiThread { result.success(status) }
                        }
                    }

                    "getDecks" -> {
                        ioExecutor.execute {
                            try {
                                val decks = client.getDecks()
                                runOnUiThread { result.success(decks) }
                            } catch (e: AnkiApiException) {
                                runOnUiThread { result.error(e.code, e.message, e.details) }
                            } catch (e: SecurityException) {
                                runOnUiThread {
                                    result.error(
                                        "ANKI_PERMISSION_DENIED",
                                        "SecurityException: ${e.message}",
                                        null
                                    )
                                }
                            } catch (e: Throwable) {
                                runOnUiThread { result.error("ANKI_UNKNOWN", e.toString(), null) }
                            }
                        }
                    }

                    "getTodayNewCards" -> {
                        val limit = call.argument<Int>("limit") ?: 20
                        val deckId = (call.argument<Number>("deckId") ?: 0).toLong()
                        ioExecutor.execute {
                            try {
                                val cards = client.getTodayNewCards(deckId = deckId, limit = limit)
                                runOnUiThread { result.success(cards) }
                            } catch (e: AnkiApiException) {
                                runOnUiThread { result.error(e.code, e.message, e.details) }
                            } catch (e: SecurityException) {
                                runOnUiThread {
                                    result.error(
                                        "ANKI_PERMISSION_DENIED",
                                        "SecurityException: ${e.message}",
                                        null
                                    )
                                }
                            } catch (e: Throwable) {
                                runOnUiThread { result.error("ANKI_UNKNOWN", e.toString(), null) }
                            }
                        }
                    }

                    "appendToNoteField" -> {
                        val noteId = (call.argument<Number>("noteId") ?: 0).toLong()
                        val modelId = (call.argument<Number>("modelId") ?: 0).toLong()
                        val targetFieldKey = call.argument<String>("targetFieldKey") ?: ""
                        val generatedText = call.argument<String>("generatedText") ?: ""
                        ioExecutor.execute {
                            try {
                                val res = client.appendToNoteField(
                                    noteId = noteId,
                                    modelId = modelId,
                                    targetFieldKey = targetFieldKey,
                                    generatedText = generatedText,
                                )
                                runOnUiThread { result.success(res) }
                            } catch (e: AnkiApiException) {
                                runOnUiThread { result.error(e.code, e.message, e.details) }
                            } catch (e: SecurityException) {
                                runOnUiThread {
                                    result.error(
                                        "ANKI_PERMISSION_DENIED",
                                        "SecurityException: ${e.message}",
                                        null
                                    )
                                }
                            } catch (e: Throwable) {
                                runOnUiThread { result.error("ANKI_UNKNOWN", e.toString(), null) }
                            }
                        }
                    }

                    "openPlayStore" -> {
                        val ok = client.openPlayStore()
                        if (ok) result.success(true) else result.error(
                            "INTENT_FAILED",
                            "Failed to open Play Store",
                            null
                        )
                    }

                    "openAnkiDroid" -> {
                        val ok = client.openAnkiDroid()
                        if (ok) result.success(true) else result.error(
                            "INTENT_FAILED",
                            "Failed to open AnkiDroid",
                            null
                        )
                    }

                    "requestAnkiPermission" -> {
                        if (pendingPermissionResult != null) {
                            result.error(
                                "PERMISSION_REQUEST_IN_PROGRESS",
                                "Permission request already in progress",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            ankiPermission
                        ) == PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            result.success(true)
                            return@setMethodCallHandler
                        }

                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(ankiPermission),
                            ankiPermissionRequestCode
                        )
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != ankiPermissionRequestCode) return

        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    override fun onDestroy() {
        ioExecutor.shutdown()
        super.onDestroy()
    }
}
