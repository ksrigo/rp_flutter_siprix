package com.ringplus.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Check if launched via deep link for incoming call BEFORE super.onCreate
        // This must happen before the activity is created to avoid showing splash
        val isCallDeepLink = intent?.data?.let { uri ->
            uri.scheme == "ringplus" && uri.host == "call"
        } ?: false

        // Set theme before calling super - this prevents splash screen from showing
        if (isCallDeepLink) {
            setTheme(R.style.TransparentTheme)
            android.util.Log.d("MainActivity", "Deep link detected - using TransparentTheme")
        }
        // Note: LaunchTheme is already set in AndroidManifest for normal launches

        super.onCreate(savedInstanceState)
    }
}
