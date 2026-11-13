package com.jeronimotech.mzd_owner

import android.content.Context
import com.oguzhnatly.flutter_android_auto.FAAConstants
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

/** Shares one Flutter engine between the phone UI and the Android Auto car service. */
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(FAAConstants.flutterEngineId)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterEngineCache.getInstance().put(FAAConstants.flutterEngineId, flutterEngine)
        super.configureFlutterEngine(flutterEngine)
    }
}
