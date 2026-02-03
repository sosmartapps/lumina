package com.carecompanion.app

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

/**
 * Device Admin Receiver for Lumina
 * Enables app protection features like preventing uninstallation
 */
class LuminaDeviceAdminReceiver : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Toast.makeText(context, "App protection enabled", Toast.LENGTH_SHORT).show()
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Toast.makeText(context, "App protection disabled", Toast.LENGTH_SHORT).show()
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        return "Warning: Disabling protection will allow the app to be uninstalled. Only caregivers should disable this."
    }

    companion object {
        fun getComponentName(context: Context): android.content.ComponentName {
            return android.content.ComponentName(context, LuminaDeviceAdminReceiver::class.java)
        }
    }
}
