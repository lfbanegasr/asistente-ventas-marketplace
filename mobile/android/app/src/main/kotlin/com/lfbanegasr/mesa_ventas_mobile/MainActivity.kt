package com.lfbanegasr.mesa_ventas_mobile

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.lfbanegasr.mesa_ventas_mobile/speech"
    private val SPEECH_REQUEST_CODE = 0x50E
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startListening") {
                if (pendingResult != null) {
                    result.error("ALREADY_ACTIVE", "Ya hay una escucha activa", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                try {
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es-BO")
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "es-BO")
                        putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, "es-BO")
                        putExtra(RecognizerIntent.EXTRA_PROMPT, "Habla tu comando o consulta...")
                    }
                    startActivityForResult(intent, SPEECH_REQUEST_CODE)
                } catch (e: Exception) {
                    pendingResult = null
                    result.error("UNAVAILABLE", "Reconocimiento de voz no disponible: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SPEECH_REQUEST_CODE) {
            val result = pendingResult
            pendingResult = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                val matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                if (!matches.isNullOrEmpty()) {
                    result?.success(matches[0])
                } else {
                    result?.success("")
                }
            } else {
                result?.success("")
            }
        }
    }
}
