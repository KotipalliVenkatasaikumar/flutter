package com.corenuts.ajna

import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The Android half of the parking receipt printer.
 *
 * Dart renders the receipt to ESC/POS and sends the bytes here; this hands them
 * to the terminal's printer. Everything above it — what a receipt says, how it
 * is laid out, when it prints, what a failure looks like to the operator — is
 * already written and does not change when this file does.
 *
 * ## Filling this in when the Pine Labs kit arrives
 *
 * 1. Add their printer AAR/dependency to `android/app/build.gradle`.
 * 2. In [isAvailable], report whether this build is running on a terminal with a
 *    roll. Model detection is usually `Build.MANUFACTURER` / `Build.MODEL`, but
 *    prefer whatever probe their SDK offers — a device list goes stale.
 * 3. In [printBytes], pass the ESC/POS through. If their SDK takes raw bytes,
 *    that is the whole job. If it insists on its own line/formatting API, do not
 *    translate here: add a renderer beside `EscPosRenderer` on the Dart side and
 *    send a structured payload instead, so the receipt stays in one place.
 * 4. Map their status codes to a sentence an operator can act on — "Out of
 *    paper", "Printer cover is open". The Dart side shows [MESSAGE] as-is and
 *    deliberately never shows a code.
 *
 * Until then every call answers "no printer here", which is what makes the same
 * build run on an ordinary phone: Dart falls back to producing a PDF.
 */
object ParkingPrinterPlugin {

    private const val TAG = "ParkingPrinter"
    private const val CHANNEL = "com.corenuts.ajna/parking_printer"

    /** Keys in the reply map. Mirrored in `pinelabs_printer.dart`. */
    private const val OK = "ok"
    private const val MESSAGE = "message"
    private const val RETRYABLE = "retryable"

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(isAvailable())

                    "printBytes" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val kind = call.argument<String>("kind") ?: "RECEIPT"
                        val reference = call.argument<String>("reference") ?: ""
                        result.success(printBytes(bytes, kind, reference))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Whether this device has a receipt printer.
     *
     * TODO(pinelabs): probe the terminal through their SDK and return the real
     * answer. Returning false here is what sends Dart to the PDF fallback.
     */
    private fun isAvailable(): Boolean = false

    /**
     * TODO(pinelabs): hand [bytes] to the terminal printer and report what
     * happened.
     *
     * Returning ok = false with retryable = true offers the operator a Retry;
     * use it for paper, cover and busy states. Reserve retryable = false for
     * "there is no printer", which stops the app asking again.
     */
    private fun printBytes(bytes: ByteArray?, kind: String, reference: String): Map<String, Any> {
        Log.i(TAG, "print request ignored — no printer integration in this build ($kind $reference, ${bytes?.size ?: 0} bytes)")
        return mapOf(
            OK to false,
            MESSAGE to "No printer on this device.",
            RETRYABLE to false,
        )
    }
}
