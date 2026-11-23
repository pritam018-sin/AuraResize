package com.aurastudio.sarkariresize.sarkari_resize

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL_PDF = "com.aurastudio.aura_resize/pdf_renderer"
    private var pendingPickResult: MethodChannel.Result? = null
    private val REQUEST_PICK_PDF = 9921

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_PDF).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickPdf" -> {
                    pendingPickResult = result
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/pdf"
                        }
                        startActivityForResult(intent, REQUEST_PICK_PDF)
                    } catch (e: Exception) {
                        pendingPickResult?.error("PICK_ERROR", e.localizedMessage, null)
                        pendingPickResult = null
                    }
                }
                "getPageCount" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    try {
                        val file = File(filePath)
                        val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                        val renderer = PdfRenderer(pfd)
                        val count = renderer.pageCount
                        renderer.close()
                        pfd.close()
                        result.success(count)
                    } catch (e: Exception) {
                        result.error("PDF_ERROR", e.localizedMessage, null)
                    }
                }
                "renderPage" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val pageIndex = call.argument<Int>("pageIndex") ?: 0
                    val scale = (call.argument<Double>("scale") ?: 1.0).toFloat()
                    val quality = call.argument<Int>("quality") ?: 85
                    try {
                        val file = File(filePath)
                        val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                        val renderer = PdfRenderer(pfd)
                        if (pageIndex < 0 || pageIndex >= renderer.pageCount) {
                            renderer.close()
                            pfd.close()
                            result.error("INVALID_PAGE", "Page index out of range", null)
                            return@setMethodCallHandler
                        }
                        val page = renderer.openPage(pageIndex)
                        val targetWidth = (page.width * scale).toInt().coerceAtLeast(1)
                        val targetHeight = (page.height * scale).toInt().coerceAtLeast(1)
                        val bitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        page.close()
                        renderer.close()
                        pfd.close()

                        val stream = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(10, 100), stream)
                        val bytes = stream.toByteArray()
                        bitmap.recycle()
                        result.success(bytes)
                    } catch (e: Exception) {
                        result.error("RENDER_ERROR", e.localizedMessage, null)
                    }
                }
                "renderAllPages" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val scale = (call.argument<Double>("scale") ?: 1.0).toFloat()
                    val quality = call.argument<Int>("quality") ?: 85
                    try {
                        val file = File(filePath)
                        val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                        val renderer = PdfRenderer(pfd)
                        val count = renderer.pageCount
                        val pagesList = mutableListOf<ByteArray>()

                        for (i in 0 until count) {
                            val page = renderer.openPage(i)
                            val targetWidth = (page.width * scale).toInt().coerceAtLeast(1)
                            val targetHeight = (page.height * scale).toInt().coerceAtLeast(1)
                            val bitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
                            bitmap.eraseColor(Color.WHITE)
                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            page.close()

                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(10, 100), stream)
                            pagesList.add(stream.toByteArray())
                            bitmap.recycle()
                        }
                        renderer.close()
                        pfd.close()
                        result.success(pagesList)
                    } catch (e: Exception) {
                        result.error("RENDER_ALL_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_PDF) {
            if (resultCode == RESULT_OK && data?.data != null) {
                val uri = data.data!!
                try {
                    val fileName = "selected_doc_${System.currentTimeMillis()}.pdf"
                    val tempFile = File(cacheDir, fileName)
                    contentResolver.openInputStream(uri)?.use { inStream ->
                        tempFile.outputStream().use { outStream ->
                            inStream.copyTo(outStream)
                        }
                    }
                    pendingPickResult?.success(tempFile.absolutePath)
                } catch (e: Exception) {
                    pendingPickResult?.error("FILE_ERROR", e.localizedMessage, null)
                }
            } else {
                pendingPickResult?.success(null)
            }
            pendingPickResult = null
        }
    }
}
