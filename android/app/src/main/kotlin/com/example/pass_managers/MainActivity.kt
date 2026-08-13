package com.example.pass_managers

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "pass_managers/file_saver"

        private const val METHOD_SAVE_PDF = "savePdf"
        private const val METHOD_SAVE_BACKUP = "saveBackup"
        private const val METHOD_OPEN_PDF = "openPdf"

        private const val REQUEST_CREATE_PDF = 9001
        private const val REQUEST_CREATE_BACKUP = 9002
    }

    private var pendingBytes: ByteArray? = null
    private var pendingFileName: String? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingRequestCode: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                METHOD_SAVE_PDF -> {
                    createDocument(
                        call = call,
                        result = result,
                        requestCode = REQUEST_CREATE_PDF,
                        mimeType = "application/pdf"
                    )
                }

                METHOD_SAVE_BACKUP -> {
                    createDocument(
                        call = call,
                        result = result,
                        requestCode = REQUEST_CREATE_BACKUP,
                        mimeType = "application/octet-stream"
                    )
                }

                METHOD_OPEN_PDF -> {
                    openPdf(
                        call = call,
                        result = result
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun createDocument(
        call: MethodCall,
        result: MethodChannel.Result,
        requestCode: Int,
        mimeType: String
    ) {
        if (pendingResult != null) {
            result.error(
                "SAVE_IN_PROGRESS",
                "Another file save operation is already in progress.",
                null
            )
            return
        }

        val fileName = call.argument<String>("fileName")
        val bytes = call.argument<ByteArray>("bytes")

        if (fileName.isNullOrBlank()) {
            result.error(
                "INVALID_FILE_NAME",
                "File name is empty.",
                null
            )
            return
        }

        if (bytes == null || bytes.isEmpty()) {
            result.error(
                "INVALID_DATA",
                "File data is empty.",
                null
            )
            return
        }

        pendingBytes = bytes.copyOf()
        pendingFileName = fileName
        pendingResult = result
        pendingRequestCode = requestCode

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }

        try {
            startActivityForResult(intent, requestCode)
        } catch (exception: Exception) {
            clearPendingSave()

            result.error(
                "LAUNCH_FAILED",
                exception.message ?: "Could not open the file picker.",
                null
            )
        }
    }

    private fun openPdf(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val uriString = call.argument<String>("uri")

        if (uriString.isNullOrBlank()) {
            result.error(
                "INVALID_URI",
                "PDF URI is empty.",
                null
            )
            return
        }

        val uri = try {
            Uri.parse(uriString)
        } catch (exception: Exception) {
            result.error(
                "INVALID_URI",
                exception.message ?: "Invalid PDF URI.",
                null
            )
            return
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(
                uri,
                "application/pdf"
            )

            addCategory(Intent.CATEGORY_DEFAULT)

            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )

            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK
            )
        }

        try {
            startActivity(intent)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.error(
                "NO_PDF_APP",
                "No application is available to open PDF files.",
                null
            )
        } catch (exception: Exception) {
            result.error(
                "OPEN_PDF_FAILED",
                exception.message ?: "Failed to open PDF.",
                null
            )
        }
    }

    @Deprecated(
        "Deprecated in Android SDK, but retained for Flutter compatibility."
    )
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != REQUEST_CREATE_PDF &&
            requestCode != REQUEST_CREATE_BACKUP
        ) {
            return
        }

        val result = pendingResult
        val bytes = pendingBytes

        clearPendingSave()

        if (result == null) {
            return
        }

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data

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
                "File data is not available.",
                null
            )
            return
        }

        try {
            val outputStream =
                contentResolver.openOutputStream(uri)
                    ?: throw IOException(
                        "Could not open output stream."
                    )

            outputStream.use {
                it.write(bytes)
                it.flush()
            }

            /*
             * For both PDF and backup we return the selected URI.
             *
             * Backup behavior is therefore unchanged.
             *
             * PdfExportService is responsible for subsequently
             * calling openPdf for PDF files.
             */
            result.success(uri.toString())

        } catch (exception: Exception) {
            result.error(
                "SAVE_FAILED",
                exception.message ?: "Failed to save file.",
                null
            )
        }
    }

    private fun clearPendingSave() {
        pendingBytes = null
        pendingFileName = null
        pendingResult = null
        pendingRequestCode = null
    }

    override fun onDestroy() {
        pendingResult?.let {
            try {
                it.error(
                    "ACTIVITY_DESTROYED",
                    "Android activity was destroyed before the file was saved.",
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
