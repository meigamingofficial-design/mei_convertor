package com.meigaming.meiconvertor

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val FILES_CHANNEL = "com.meigaming.meiconvertor/files"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveFileToPublic" -> {
                        val tempPath = call.argument<String>("tempPath")
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType")
                        if (tempPath != null && fileName != null) {
                            saveFileToPublic(tempPath, fileName, mimeType, result)
                        } else {
                            result.error("INVALID_ARG", "tempPath or fileName is null", null)
                        }
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path")
                        if (path != null) openFile(path, result)
                        else result.error("INVALID_ARG", "path is null", null)
                    }
                    "openFolder" -> {
                        val path = call.argument<String>("path")
                        if (path != null) openFolder(path, result)
                        else result.error("INVALID_ARG", "path is null", null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openFile(path: String, result: MethodChannel.Result) {
        try {
            val uri: Uri
            var mimeType: String?

            if (path.startsWith("content://")) {
                uri = Uri.parse(path)
                mimeType = contentResolver.getType(uri)
            } else {
                // For absolute file paths, find the content URI via MediaStore
                // so the system can grant proper read access
                val file = File(path)
                if (!file.exists()) {
                    result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
                    return
                }

                // Determine mime type from extension
                val ext = path.substringAfterLast('.', "").lowercase()
                mimeType = when (ext) {
                    "pdf" -> "application/pdf"
                    "jpg", "jpeg" -> "image/jpeg"
                    "png" -> "image/png"
                    "webp" -> "image/webp"
                    "bmp" -> "image/bmp"
                    "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                    "txt" -> "text/plain"
                    else -> "*/*"
                }

                // Try to find content URI from MediaStore
                var contentUri: Uri? = null
                val collection = MediaStore.Files.getContentUri("external")
                val projection = arrayOf(MediaStore.MediaColumns._ID)
                val selection = "${MediaStore.MediaColumns.DATA} = ?"
                val selectionArgs = arrayOf(path)
                contentResolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                        contentUri = android.content.ContentUris.withAppendedId(collection, id)
                    }
                }

                uri = contentUri ?: Uri.fromFile(file)
            }

            val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType ?: "*/*")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(viewIntent, "Open with")
            startActivity(chooser)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", "Could not open file: ${e.message}", null)
        }
    }

    private fun saveFileToPublic(tempPath: String, fileName: String, mimeType: String?, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val resolver = contentResolver
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    if (mimeType != null) {
                        put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    }
                    put(MediaStore.MediaColumns.RELATIVE_PATH, "Documents/MeiConvertor")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }

                val collection = MediaStore.Files.getContentUri("external")
                val uri = resolver.insert(collection, contentValues)
                if (uri == null) {
                    result.error("SAVE_FAILED", "Failed to insert MediaStore record", null)
                    return
                }

                resolver.openOutputStream(uri).use { outputStream ->
                    if (outputStream == null) {
                        result.error("SAVE_FAILED", "Failed to open output stream", null)
                        return
                    }
                    File(tempPath).inputStream().use { inputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }

                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)

                // Get absolute path
                val projection = arrayOf(MediaStore.MediaColumns.DATA)
                val cursor = resolver.query(uri, projection, null, null, null)
                var absolutePath = ""
                cursor?.use { c ->
                    if (c.moveToFirst()) {
                        absolutePath = c.getString(c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA))
                    }
                }
                result.success(absolutePath.ifEmpty { uri.toString() })
            } catch (e: Exception) {
                result.error("SAVE_FAILED", e.message, null)
            }
        } else {
            try {
                val publicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
                val meiDir = File(publicDir, "MeiConvertor")
                if (!meiDir.exists()) meiDir.mkdirs()
                val destFile = File(meiDir, fileName)
                File(tempPath).copyTo(destFile, overwrite = true)
                result.success(destFile.absolutePath)
            } catch (e: Exception) {
                result.error("SAVE_FAILED", e.message, null)
            }
        }
    }

    private fun openFolder(path: String, result: MethodChannel.Result) {
        try {
            // Always target the public Documents/MeiConvertor folder,
            // regardless of whether the path is internal app storage or external.
            val relativePath = if (path.contains("MeiConvertor")) {
                "Documents/MeiConvertor"
            } else {
                val rootPath = Environment.getExternalStorageDirectory().absolutePath
                if (path.startsWith(rootPath)) {
                    path.substring(rootPath.length).trimStart('/')
                } else {
                    "Documents"
                }
            }

            // Ensure the public directory exists
            val publicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
            val meiDir = File(publicDir, "MeiConvertor")
            if (!meiDir.exists()) meiDir.mkdirs()

            // Strategy 1: DocumentsContract for Android 11+ / API 30+ (Direct & Fast)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    val authority = "com.android.externalstorage.documents"
                    val documentId = "primary:$relativePath"
                    val uri = android.provider.DocumentsContract.buildDocumentUri(authority, documentId)
                    
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        addCategory(Intent.CATEGORY_DEFAULT)
                        setDataAndType(uri, "vnd.android.document/directory")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                    startActivity(intent)
                    result.success("exact_modern_documents_direct")
                    return
                } catch (e: Exception) {
                    android.util.Log.w("MeiConvertor", "DocumentsContract strategy failed: ${e.message}")
                }
            }

            // Fallback Strategy: System Folder Tree Picker (Universal fallback)
            try {
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                startActivity(intent)
                result.success("picker")
            } catch (e: Exception) {
                result.error("OPEN_FAILED", "Could not open any file manager: ${e.message}", null)
            }
        } catch (e: Exception) {
            result.error("CRITICAL_ERROR", e.message, null)
        }
    }
}
