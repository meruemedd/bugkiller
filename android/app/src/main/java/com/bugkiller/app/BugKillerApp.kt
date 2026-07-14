package com.bugkiller.app

/**
 * BugKiller Android 入口骨架。
 * 用 Android Studio 打开 android/ 目录生成完整 Gradle 工程后，将此逻辑接入 MainActivity。
 */
object BugKillerApp {
    const val TAG = "BugKiller"
    // 联调时改成电脑局域网 IP
    const val API_BASE = "http://10.0.2.2:8787" // 模拟器访问宿主机

    fun pingUrl(): String = "$API_BASE/api/ping"
}
