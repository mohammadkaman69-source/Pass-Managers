package com.example.pass_managers

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL =
            "pass_managers/file_saver"

        private const val METHOD_SAVE_PDF =
            "savePdf"

        private const val REQUEST_CREATE_PDF =
            9001
    }

    private var pendingPdfBytes: ByteArray? = null

    private var pendingFileName: String? = null

    private var pendingResult:
        MethodChannel.Result? = null

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
                        call = call,
                        result = result
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun savePdf(
        call: MethodCall,
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

        if (bytes == null || bytes.isEmpty()) {
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
            startActivityForResult(
                intent,
                REQUEST_CREATE_PDF
            )
        } catch (exception: Exception) {

            clearPendingSave()

            result.error(
                "LAUNCH_FAILED",
                exception.message,
                null
            )
        }
    }

    @Deprecated(
        "Deprecated in Android SDK, but retained for compatibility with FlutterActivity."
    )
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: android.content.Intent?
    ) {
        super.onActivityResult(
            requestCode,
            resultCode,
            data
        )

        if (requestCode != REQUEST_CREATE_PDF) {
            return
        }

        val result =
            pendingResult

        val bytes =
            pendingPdfBytes

        clearPendingSave()

        if (result == null) {
            return
        }

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri =
            data?.data

        if (uri == null) {
            result.error(
                "NO_URI",
                "No destination file was selected.",
                null
            )
            return
        }

        if (bytes == null || bytes.isEmpty()) {
            result.error(
                "NO_DATA",
                "PDF data is not available.",
                null
            )
            return
        }

        try {
            val outputStream =
                contentResolver.openOutputStream(
                    uri
                )

            if (outputStream == null) {
                throw IOException(
                    "Could not open output stream."
                )
            }

            outputStream.use {
                it.write(bytes)
                it.flush()
            }

            result.success(
                uri.toString()
            )

        } catch (exception: Exception) {

            result.error(
                "SAVE_FAILED",
                exception.message
                    ?: "Failed to save PDF.",
                null
            )
        }
    }

    private fun clearPendingSave() {
        pendingPdfBytes = null
        pendingFileName = null
        pendingResult = null
    }

    override fun onDestroy() {
        /*
         * اگر Activity در حالی Destroy شود که پنجره
         * انتخاب فایل باز است، Promise سمت Flutter
         * نباید با یک Result قدیمی باقی بماند.
         */
        pendingResult?.let {
            try {
                it.error(
                    "ACTIVITY_DESTROYED",
                    "Android activity was destroyed before the PDF was saved.",
                    null
                )
            } catch (_: Exception) {
                // Result may already have been completed.
            }
        }

        clearPendingSave()

        super.onDestroy()
    }
}
