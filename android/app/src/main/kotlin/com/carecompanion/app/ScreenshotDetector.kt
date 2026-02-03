package com.carecompanion.app

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

/**
 * Detects when screenshots are taken on Android and notifies Flutter.
 *
 * Uses ContentObserver to monitor the MediaStore for new screenshots.
 * This is part of the Lumina screenshot feedback feature.
 */
class ScreenshotDetector : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var screenshotObserver: ScreenshotObserver? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "com.carecompanion/screenshot"
        )
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startListening" -> {
                startListening()
                result.success(null)
            }
            "stopListening" -> {
                stopListening()
                result.success(null)
            }
            "getLatestScreenshot" -> {
                val screenshot = getLatestScreenshot()
                result.success(screenshot)
            }
            else -> result.notImplemented()
        }
    }

    private fun startListening() {
        val ctx = context ?: return

        if (screenshotObserver == null) {
            screenshotObserver = ScreenshotObserver(Handler(Looper.getMainLooper()), ctx) {
                // Notify Flutter when screenshot is detected
                Handler(Looper.getMainLooper()).post {
                    channel.invokeMethod("onScreenshot", null)
                }
            }

            ctx.contentResolver.registerContentObserver(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                true,
                screenshotObserver!!
            )
        }
    }

    private fun stopListening() {
        screenshotObserver?.let {
            context?.contentResolver?.unregisterContentObserver(it)
            screenshotObserver = null
        }
    }

    private fun getLatestScreenshot(): String? {
        val ctx = context ?: return null

        // Query for the most recent image that looks like a screenshot
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DATA,
            MediaStore.Images.Media.DATE_ADDED,
            MediaStore.Images.Media.DISPLAY_NAME
        )

        val selection = "${MediaStore.Images.Media.DISPLAY_NAME} LIKE ? OR ${MediaStore.Images.Media.DISPLAY_NAME} LIKE ?"
        val selectionArgs = arrayOf("%screenshot%", "%Screenshot%")

        val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"

        try {
            ctx.contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                sortOrder
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
                    val path = cursor.getString(dataColumn)

                    // Verify file exists
                    if (File(path).exists()) {
                        return path
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopListening()
        channel.setMethodCallHandler(null)
        context = null
    }

    /**
     * ContentObserver that watches for new screenshots in the MediaStore
     */
    private class ScreenshotObserver(
        handler: Handler,
        private val context: Context,
        private val onScreenshot: () -> Unit
    ) : ContentObserver(handler) {

        private var lastTimestamp = System.currentTimeMillis()

        override fun onChange(selfChange: Boolean, uri: Uri?) {
            super.onChange(selfChange, uri)

            // Debounce - avoid multiple triggers for same screenshot
            val now = System.currentTimeMillis()
            if (now - lastTimestamp < 1000) {
                return
            }

            // Check if this is actually a screenshot
            if (isScreenshot(uri)) {
                lastTimestamp = now
                onScreenshot()
            }
        }

        private fun isScreenshot(uri: Uri?): Boolean {
            if (uri == null) return false

            val projection = arrayOf(
                MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.DATA
            )

            try {
                context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameColumn =
                            cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
                        val dataColumn =
                            cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)

                        val name = cursor.getString(nameColumn)?.lowercase() ?: ""
                        val path = cursor.getString(dataColumn)?.lowercase() ?: ""

                        // Check if filename or path contains "screenshot"
                        return name.contains("screenshot") ||
                                path.contains("screenshot") ||
                                path.contains("screenshots")
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            return false
        }
    }
}
