package com.carecompanion.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Boot Receiver for Lumina
 * Restores app to foreground after device restart if kiosk mode was enabled
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {

            Log.d("Lumina", "Boot completed, checking if app should launch")

            // Check if kiosk mode or auto-start is enabled
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val kioskEnabled = prefs.getBoolean("flutter.kioskModeEnabled", false)
            val autoStart = prefs.getBoolean("flutter.autoStartOnBoot", true)

            if (kioskEnabled || autoStart) {
                // Launch the main activity
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                context.startActivity(launchIntent)
            }
        }
    }
}
