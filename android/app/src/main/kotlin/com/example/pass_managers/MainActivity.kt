package com.example.pass_managers

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.DocumentsContract
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * ذخیره با دیالوگ سیستم (ACTION_CREATE_DOCUMENT):
 * کاربر می‌تواند نام و مسیر را عوض کند؛ مثل File Explorer قبلی.
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "pass_managers/file_saver"

        private const val METHOD_SAVE_PDF = "savePdf"
        private const val METHOD_SAVE_BACKUP = "saveBackup"
        private const val METHOD_OPEN_PDF = "openPdf"
        private const val METHOD_ENSURE_FOLDERS = "ensureAppFolders"
        private const val METHOD_SAVE_TO_APP_FOLDER = "saveToAppFolder"
        private const val METHOD_PICK_SAVE_BACKUP = "pickAndSaveBackup"
        private const val METHOD_PICK_SAVE_PDF = "pickAndSavePdf"

        private const val APP_FOLDER = "NexVault"
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private var pendingFileName: String? = null

    private lateinit var createDocumentLauncher: ActivityResultLauncher<String>

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)

        createDocumentLauncher = registerForActivityResult(
            ActivityResultContracts.CreateDocument("*/*")
        ) { uri: Uri? ->
            val result = pendingResult
            val bytes = pendingBytes
            pendingResult = null
            pendingBytes = null
            val name = pendingFileName
            pendingFileName = null

            if (result == null) return@registerForActivityResult

            if (uri == null || bytes == null) {
                // کاربر انصراف داد
                result.success(null)
                return@registerForActivityResult
            }

            try {
                contentResolver.openOutputStream(uri)?.use { out ->
                    out.write(bytes)
                    out.flush()
                } ?: throw IOException("Could not open output stream for selected location.")
                result.success(uri.toString())
            } catch (e: Exception) {
                result.error(
                    "SAVE_FAILED",
                    e.message ?: "Failed to write file to selected location.",
                    null
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_ENSURE_FOLDERS -> {
                    try {
                        result.success(ensurePublicFolders())
                    } catch (e: Exception) {
                        result.error(
                            "FOLDER_FAILED",
                            e.message ?: "Could not prepare NexVault folder.",
                            null
                        )
                    }
                }

                METHOD_SAVE_TO_APP_FOLDER,
                METHOD_SAVE_PDF,
                METHOD_SAVE_BACKUP -> {
                    // این متدها هم دیالوگ سیستم را باز می‌کنند
                    launchSaveDialog(call, result, defaultMime(call.method))
                }

                METHOD_PICK_SAVE_BACKUP -> launchSaveDialog(
                    call,
                    result,
                    "application/octet-stream"
                )
                METHOD_PICK_SAVE_PDF -> launchSaveDialog(
                    call,
                    result,
                    "application/pdf"
                )

                METHOD_OPEN_PDF -> openPdf(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun defaultMime(method: String): String {
        return if (method.contains("pdf", ignoreCase = true)) {
            "application/pdf"
        } else {
            "application/octet-stream"
        }
    }

    /** پوشهٔ عمومی برای دیفالت (اگر ساخته شود). */
    private fun ensurePublicFolders(): Map<String, String> {
        return try {
            val root = publicAppRoot()
            mapOf("root" to root.absolutePath)
        } catch (_: Exception) {
            mapOf("root" to "Download/$APP_FOLDER")
        }
    }

    private fun publicAppRoot(): File {
        val root = File(Environment.getExternalStorageDirectory(), APP_FOLDER)
        if (!root.exists() && !root.mkdirs() && !root.exists()) {
            throw IOException("Could not create NexVault at ${root.absolutePath}")
        }
        return root
    }

    /**
     * دیالوگ File Explorer سیستم را باز می‌کند.
     * bytes از Flutter یا از فایل موقت خوانده می‌شود.
     */
    private fun launchSaveDialog(
        call: MethodCall,
        result: MethodChannel.Result,
        mimeType: String
    ) {
        if (pendingResult != null) {
            result.error("BUSY", "A save dialog is already open.", null)
            return
        }

        val fileName = call.argument<String>("fileName")
        if (fileName.isNullOrBlank()) {
            result.error("INVALID_FILE_NAME", "File name is empty.", null)
            return
        }

        val bytes: ByteArray? = call.argument<ByteArray>("bytes")
        val path = call.argument<String>("path")

        val data: ByteArray = when {
            bytes != null && bytes.isNotEmpty() -> bytes
            !path.isNullOrBlank() -> {
                val temp = File(path)
                if (!temp.exists() || !temp.isFile) {
                    result.error("INVALID_DATA", "Temporary file missing: $path", null)
                    return
                }
                val read = temp.readBytes()
                if (read.isEmpty()) {
                    result.error("INVALID_DATA", "Temporary file is empty.", null)
                    return
                }
                read
            }
            else -> {
                result.error("INVALID_DATA", "File data is empty.", null)
                return
            }
        }

        pendingResult = result
        pendingBytes = data
        pendingFileName = fileName

        try {
            // CreateDocument launcher با نام پیشنهادی
            createDocumentLauncher.launch(fileName)
        } catch (e: Exception) {
            pendingResult = null
            pendingBytes = null
            pendingFileName = null
            result.error(
                "SAVE_FAILED",
                e.message ?: "Could not open system save dialog.",
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
            result.error("INVALID_URI", "PDF URI is empty.", null)
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
            setDataAndType(uri, "application/pdf")
            addCategory(Intent.CATEGORY_DEFAULT)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
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
}
