package com.mysterwolf.lg_remote

import io.flutter.plugin.common.MethodChannel

/**
 * In-process relay between MainActivity's Flutter engine and OverlayService's
 * native overlay window. The overlay is plain native Views (no second Flutter
 * engine), so this is just a MethodChannel reference shared between whichever
 * component is currently alive.
 */
object OverlayBridge {
    var mainChannel: MethodChannel? = null

    /** True only while MainActivity's Flutter engine is actually alive and attached. */
    fun isEngineAlive(): Boolean = mainChannel != null

    fun sendCommandToMain(action: String) {
        mainChannel?.invokeMethod("overlayCommand", action)
    }
}
