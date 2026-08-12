package com.example.pass_managers

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL =
            "pass_managers/file_saver"

        private const val METHOD_SAVE_PDF =
            "savePdf"
    }

    private var pendingPdfBytes: ByteArray? = null
    private var pendingFileName: String? = null
    private var pendingResult:
        MethodChannel.Result? = null

    private val createDocumentLauncher =
        registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { activityResult ->

            val result = pendingResult
            val bytes = pendingPdfBytes

            pendingResult = null
            pendingPdfBytes = null
            pendingFileName = null

            if (result == null) {
                return@registerForActivityResult
            }

            if (activityResult.resultCode != Activity.RESULT_OK) {
                result.success(null)
                return@registerForActivityResult
            }

            val uri =
                activityResult.data?.data

            if (uri == null) {
                result.success(null)
                return@registerForActivityResult
            }

            if (bytes == null) {
                result.error(
                    "NO_DATA",
                    "PDF data is not available.",
                    null
                )
                return@registerForActivityResult
            }

            try {
                contentResolver
                    .openOutputStream(uri)
                    ?.use { outputStream ->
                        outputStream.write(bytes)
                        outputStream.flush()
                    }
                    ?: throw IOException(
                        "Could not open output stream."
                    )

                result.success(uri.toString())
            } catch (exception: Exception) {
                result.error(
                    "SAVE_FAILED",
                    exception.message,
                    null
                )
            }
        }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(
            flutterEngine
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                METHOD_SAVE_PDF -> {
                    savePdf(
                        call,
                        result
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun savePdf(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        if (pendingResult != null) {
            result.error(
                "SAVE_IN_PROGRESS",
                "Another file save operation is already in progress.",
                null
            )
            return
        }

        val fileName =
            call.argument<String>("fileName")

        val bytes =
            call.argument<ByteArray>("bytes")

        if (fileName.isNullOrBlank()) {
            result.error(
                "INVALID_FILE_NAME",
                "PDF file name is empty.",
                null
            )
            return
        }

        if (bytes == null ||
            bytes.isEmpty()
        ) {
            result.error(
                "INVALID_DATA",
                "PDF data is empty.",
                null
            )
            return
        }

        pendingPdfBytes = bytes
        pendingFileName = fileName
        pendingResult = result

        val intent =
            Intent(
                Intent.ACTION_CREATE_DOCUMENT
            ).apply {

                addCategory(
                    Intent.CATEGORY_OPENABLE
                )

                type =
                    "application/pdf"

                putExtra(
                    Intent.EXTRA_TITLE,
                    fileName
                )
            }

        try {
            createDocumentLauncher.launch(
                intent
            )
        } catch (exception: Exception) {

            pendingPdfBytes = null
            pendingFileName = null
            pendingResult = null

            result.error(
                "LAUNCH_FAILED",
                exception.message,
                null
            )
        }
    }
}
