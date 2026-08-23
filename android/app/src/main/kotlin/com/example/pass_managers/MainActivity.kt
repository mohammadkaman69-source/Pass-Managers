package com.example.pass_managers

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

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
                            e.message ?: "Could not create NexVault folder.",
                            null
                        )
                    }
                }

                METHOD_SAVE_TO_APP_FOLDER -> saveToAppFolder(call, result)
                METHOD_SAVE_PDF -> saveDirect(call, result, "application/pdf")
                METHOD_SAVE_BACKUP -> saveDirect(call, result, "application/octet-stream")

                // These method names are retained for Flutter compatibility.
                // They no longer open ACTION_CREATE_DOCUMENT: Backup and PDF
                // are always written directly into the single NexVault root.
                METHOD_PICK_SAVE_BACKUP -> saveFromTempPath(
                    call,
                    result,
                    "application/octet-stream"
                )
                METHOD_PICK_SAVE_PDF -> saveFromTempPath(
                    call,
                    result,
                    "application/pdf"
                )

                METHOD_OPEN_PDF -> openPdf(call, result)
                else -> result.notImplemented()
            }
        }
    }

    /** Creates only the single public NexVault directory. */
    private fun ensurePublicFolders(): Map<String, String> {
        val root = publicAppRoot()
        return mapOf("root" to root.absolutePath)
    }

    /** Primary shared storage root: /storage/emulated/0/NexVault */
    private fun publicAppRoot(): File {
        val root = File(Environment.getExternalStorageDirectory(), APP_FOLDER)
        if (!root.exists() && !root.mkdirs() && !root.exists()) {
            throw IOException("Could not create NexVault folder at ${root.absolutePath}")
        }
        return root
    }

    private fun saveDirect(
        call: MethodCall,
        result: MethodChannel.Result,
        mimeType: String
    ) {
        val fileName = call.argument<String>("fileName")
        val bytes = call.argument<ByteArray>("bytes")

        if (fileName.isNullOrBlank()) {
            result.error("INVALID_FILE_NAME", "File name is empty.", null)
            return
        }
        if (bytes == null || bytes.isEmpty()) {
            result.error("INVALID_DATA", "File data is empty.", null)
            return
        }

        try {
            result.success(writeToAppFolder(fileName, bytes, mimeType))
        } catch (e: Exception) {
            result.error(
                "SAVE_FAILED",
                e.message ?: "Failed to save into NexVault folder.",
                null
            )
        }
    }

    private fun saveToAppFolder(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val fileName = call.argument<String>("fileName")
        val bytes = call.argument<ByteArray>("bytes")
        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"

        if (fileName.isNullOrBlank()) {
            result.error("INVALID_FILE_NAME", "File name is empty.", null)
            return
        }
        if (bytes == null || bytes.isEmpty()) {
            result.error("INVALID_DATA", "File data is empty.", null)
            return
        }

        try {
            result.success(writeToAppFolder(fileName, bytes, mimeType))
        } catch (e: Exception) {
            result.error(
                "SAVE_FAILED",
                e.message ?: "Failed to save into NexVault folder.",
                null
            )
        }
    }

    /**
     * Reads the temporary file created by Flutter and writes it directly into
     * the single NexVault root. No Android document picker is opened and no
     * Documents/Download/backup/pdf subdirectory is involved.
     */
    private fun saveFromTempPath(
        call: MethodCall,
        result: MethodChannel.Result,
        mimeType: String
    ) {
        val fileName = call.argument<String>("fileName")
        val path = call.argument<String>("path")

        if (fileName.isNullOrBlank()) {
            result.error("INVALID_FILE_NAME", "File name is empty.", null)
            return
        }
        if (path.isNullOrBlank()) {
            result.error("INVALID_DATA", "Temporary file path is empty.", null)
            return
        }

        try {
            val temp = File(path)
            if (!temp.exists() || !temp.isFile) {
                throw IOException("Temporary file does not exist: $path")
            }
            val bytes = temp.readBytes()
            if (bytes.isEmpty()) {
                throw IOException("Temporary file is empty.")
            }
            result.success(writeToAppFolder(fileName, bytes, mimeType))
        } catch (e: Exception) {
            result.error(
                "SAVE_FAILED",
                e.message ?: "Failed to save into NexVault folder.",
                null
            )
        }
    }

    private fun writeToAppFolder(
        fileName: String,
        bytes: ByteArray,
        mimeType: String
    ): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                // This is deliberately only the app folder name. It is relative
                // to primary shared storage, so the result is /NexVault/file.
                put(MediaStore.MediaColumns.RELATIVE_PATH, APP_FOLDER)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val collection = MediaStore.Files.getContentUri("external")
            val uri = contentResolver.insert(collection, values)
                ?: throw IOException("MediaStore insert failed.")

            try {
                contentResolver.openOutputStream(uri)?.use { out ->
                    out.write(bytes)
                    out.flush()
                } ?: throw IOException("Could not open MediaStore output stream.")

                val complete = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                contentResolver.update(uri, complete, null, null)
                return uri.toString()
            } catch (e: Exception) {
                contentResolver.delete(uri, null, null)
                throw e
            }
        }

        val root = publicAppRoot()
        val file = File(root, fileName)
        FileOutputStream(file).use { out ->
            out.write(bytes)
            out.flush()
        }
        return file.absolutePath
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