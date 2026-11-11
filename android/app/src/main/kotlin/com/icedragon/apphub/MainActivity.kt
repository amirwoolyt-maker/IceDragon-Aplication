package com.icedragon.apphub

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.StorageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.StatFs
import android.os.storage.StorageManager
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingUninstall: Pair<String, Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "icedragon.apphub/android")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "dataDir" -> result.success(filesDir.absolutePath)
                "installedAppsDetailed" -> inBackground(result) { installedAppsDetailed() }
                "deviceInfo" -> inBackground(result) { deviceInfo() }
                "appIcon" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    inBackground(result) { appIcon(pkg) }
                }
                "openAppSettings" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    result.success(openAppSettings(pkg))
                }
                "uninstallApp" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    uninstallApp(pkg, result)
                }
                "launchApp" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    result.success(launchApp(pkg))
                }
                "boostMemory" -> {
                    val exclude = (call.argument<List<String>>("exclude") ?: emptyList()).toSet()
                    inBackground(result) { boostMemory(exclude) }
                }
                "openUsageAccessSettings" -> result.success(openUsageAccessSettings())
                "openVpnSettings" -> result.success(openVpnSettings())
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val subject = call.argument<String>("subject") ?: ""
                    result.success(shareText(text, subject))
                }
                "openStore" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    val store = call.argument<String>("store") ?: ""
                    val fallbackUrl = call.argument<String>("fallbackUrl") ?: ""
                    result.success(openStore(pkg, store, fallbackUrl))
                }
                "saveSecret" -> {
                    val key = call.argument<String>("key") ?: ""
                    val value = call.argument<String>("value") ?: ""
                    inBackground(result) { saveSecret(key, value) }
                }
                "readSecret" -> {
                    val key = call.argument<String>("key") ?: ""
                    inBackground(result) { readSecret(key) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun inBackground(result: Result, work: () -> Any?) {
        worker.execute {
            val value = try {
                work()
            } catch (_: Throwable) {
                null
            }
            main.post { result.success(value) }
        }
    }

    private fun isTv(config: Configuration) =
        config.uiMode and Configuration.UI_MODE_TYPE_MASK == Configuration.UI_MODE_TYPE_TELEVISION

    private fun appIcon(pkg: String): ByteArray? = runCatching {
        val drawable = packageManager.getApplicationIcon(pkg)
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }.getOrNull()

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(AppOpsManager::class.java) ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun deviceInfo(): Map<String, Any> {
        val am = getSystemService(ActivityManager::class.java)
        val memInfo = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(memInfo)
        val stat = StatFs(Environment.getDataDirectory().path)
        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "release" to (Build.VERSION.RELEASE ?: ""),
            "manufacturer" to (Build.MANUFACTURER ?: ""),
            "model" to (Build.MODEL ?: ""),
            "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: ""),
            "totalRamBytes" to memInfo.totalMem,
            "availRamBytes" to memInfo.availMem,
            "totalStorageBytes" to stat.totalBytes,
            "freeStorageBytes" to stat.availableBytes,
            "hasUsageAccess" to hasUsageAccess(),
        )
    }

    private fun installedAppsDetailed(): List<Map<String, Any>> {
        val pm = packageManager
        val withIcon = listOf(Intent.CATEGORY_LAUNCHER, Intent.CATEGORY_LEANBACK_LAUNCHER)
            .flatMap { pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(it), 0) }
            .map { it.activityInfo.packageName }
            .toSet()
        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
        }
        val usageOk = hasUsageAccess()
        val storageStats = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && usageOk) {
            getSystemService(StorageStatsManager::class.java)
        } else {
            null
        }
        val user = Process.myUserHandle()
        val result = ArrayList<Map<String, Any>>(packages.size)
        for (pkgInfo in packages) {
            val appInfo = pkgInfo.applicationInfo ?: continue
            if (appInfo.packageName == packageName) continue
            if ((appInfo.flags and ApplicationInfo.FLAG_HAS_CODE) == 0) continue

            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0 &&
                (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0
            val verCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pkgInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                pkgInfo.versionCode.toLong()
            }
            val category = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) appInfo.category else -1
            @Suppress("DEPRECATION")
            val isGame = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) category == ApplicationInfo.CATEGORY_GAME else false) ||
                ((appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0)
            val minSdk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) appInfo.minSdkVersion else 24
            val installer = runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    pm.getInstallSourceInfo(pkgInfo.packageName).installingPackageName ?: ""
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(pkgInfo.packageName) ?: ""
                }
            }.getOrDefault("")

            var apkBytes = 0L
            appInfo.sourceDir?.let { path ->
                val f = File(path)
                if (f.exists()) apkBytes += f.length()
            }
            appInfo.splitSourceDirs?.forEach { path ->
                val f = File(path)
                if (f.exists()) apkBytes += f.length()
            }

            var dataBytes = 0L
            var cacheBytes = 0L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && storageStats != null) {
                runCatching {
                    val uuid = runCatching { appInfo.storageUuid }.getOrNull() ?: StorageManager.UUID_DEFAULT
                    val stats = storageStats.queryStatsForPackage(uuid, pkgInfo.packageName, user)
                    if (stats.appBytes > apkBytes) apkBytes = stats.appBytes
                    dataBytes = stats.dataBytes
                    cacheBytes = stats.cacheBytes
                }
            }

            val reqPerms = pkgInfo.requestedPermissions?.filterNotNull() ?: emptyList()
            val permFlags = pkgInfo.requestedPermissionsFlags
            val grantedPerms = ArrayList<String>()
            if (permFlags != null) {
                for (i in reqPerms.indices) {
                    if (i < permFlags.size && (permFlags[i] and PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0) {
                        grantedPerms.add(reqPerms[i])
                    }
                }
            }

            result.add(
                mapOf(
                    "package" to pkgInfo.packageName,
                    "label" to appInfo.loadLabel(pm).toString(),
                    "launcher" to (pkgInfo.packageName in withIcon),
                    "system" to isSystem,
                    "versionName" to (pkgInfo.versionName ?: ""),
                    "versionCode" to verCode,
                    "firstInstallTime" to pkgInfo.firstInstallTime,
                    "lastUpdateTime" to pkgInfo.lastUpdateTime,
                    "category" to category,
                    "isGame" to isGame,
                    "minSdk" to minSdk,
                    "targetSdk" to appInfo.targetSdkVersion,
                    "installer" to installer,
                    "apkBytes" to apkBytes,
                    "dataBytes" to dataBytes,
                    "cacheBytes" to cacheBytes,
                    "permissions" to reqPerms,
                    "grantedPermissions" to grantedPerms,
                ),
            )
        }
        return result
    }

    private fun openAppSettings(pkg: String): Boolean = runCatching {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$pkg")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        true
    }.getOrDefault(false)

    private fun isPackageInstalled(pkg: String): Boolean = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(pkg, 0)
        }
        true
    }.getOrDefault(false)

    private fun uninstallApp(pkg: String, result: Result) {
        if (pkg.isBlank() || pkg == packageName || !isPackageInstalled(pkg)) {
            result.success(false)
            return
        }
        pendingUninstall?.second?.success(false)
        pendingUninstall = pkg to result
        val intent = Intent(Intent.ACTION_DELETE).apply {
            data = Uri.parse("package:$pkg")
            putExtra(Intent.EXTRA_RETURN_RESULT, true)
        }
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, UNINSTALL_REQUEST)
        } catch (_: Exception) {
            pendingUninstall = null
            result.success(false)
        }
    }

    private fun launchApp(pkg: String): Boolean = runCatching {
        val pm = packageManager
        val intent = pm.getLaunchIntentForPackage(pkg)
            ?: if (isTv(resources.configuration)) pm.getLeanbackLaunchIntentForPackage(pkg) else null
        if (intent == null) return@runCatching false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        true
    }.getOrDefault(false)

    private fun boostMemory(exclude: Set<String>): Map<String, Any> {
        val am = getSystemService(ActivityManager::class.java) ?: return emptyMap()
        val beforeInfo = ActivityManager.MemoryInfo()
        am.getMemoryInfo(beforeInfo)
        val beforeRunning = runCatching {
            am.runningAppProcesses
                ?.mapNotNull { it.processName?.substringBefore(':') }
                ?.toSet()
        }.getOrNull() ?: emptySet()
        val pm = packageManager
        @Suppress("DEPRECATION")
        val apps = pm.getInstalledApplications(0)
        for (app in apps) {
            val pkg = app.packageName
            if (pkg == packageName || pkg in exclude) continue
            if ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0) continue
            if ((app.flags and ApplicationInfo.FLAG_PERSISTENT) != 0) continue
            runCatching { am.killBackgroundProcesses(pkg) }
        }
        System.gc()
        val afterRunning = runCatching {
            am.runningAppProcesses
                ?.mapNotNull { it.processName?.substringBefore(':') }
                ?.toSet()
        }.getOrNull() ?: emptySet()
        val confirmedStopped = beforeRunning.count { pkg ->
            pkg != packageName && pkg !in exclude && pkg !in afterRunning
        }
        val afterInfo = ActivityManager.MemoryInfo()
        am.getMemoryInfo(afterInfo)
        return mapOf(
            "beforeAvailBytes" to beforeInfo.availMem,
            "afterAvailBytes" to afterInfo.availMem,
            "totalBytes" to afterInfo.totalMem,
            "touchedCount" to confirmedStopped,
        )
    }

    private fun openUsageAccessSettings(): Boolean = runCatching {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    }.getOrDefault(false)

    private fun openVpnSettings(): Boolean = runCatching {
        startActivity(Intent(Settings.ACTION_VPN_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    }.getOrDefault(false)

    private fun shareText(text: String, subject: String): Boolean = runCatching {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            if (subject.isNotBlank()) putExtra(Intent.EXTRA_SUBJECT, subject)
        }
        startActivity(Intent.createChooser(send, subject.ifBlank { getString(R.string.app_name) }))
        true
    }.getOrDefault(false)

    private fun openStore(pkg: String, store: String, fallbackUrl: String): Boolean {
        val validPkg = Regex("^[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z0-9_]+)+$").matches(pkg)
        val deepUri = if (validPkg) {
            when (store) {
                "bazaar" -> "bazaar://details?id=$pkg"
                "myket" -> "myket://details?id=$pkg"
                "googlePlay" -> "market://details?id=$pkg"
                else -> ""
            }
        } else {
            ""
        }
        if (deepUri.isNotEmpty()) {
            val launched = runCatching {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepUri)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                true
            }.getOrDefault(false)
            if (launched) return true
        }
        val parsedFallback = runCatching { Uri.parse(fallbackUrl.trim()) }.getOrNull()
        if (parsedFallback != null &&
            parsedFallback.scheme.equals("https", ignoreCase = true) &&
            !parsedFallback.host.isNullOrBlank()
        ) {
            return runCatching {
                startActivity(
                    Intent(Intent.ACTION_VIEW, parsedFallback).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    },
                )
                true
            }.getOrDefault(false)
        }
        return false
    }

    private fun getOrCreateAesKey(): SecretKey {
        val ks = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        val existing = ks.getEntry(HUB_KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (existing != null) return existing.secretKey
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
        generator.init(
            KeyGenParameterSpec.Builder(
                HUB_KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private fun saveSecret(key: String, value: String): Boolean {
        if (key.isBlank()) return false
        val prefs = getSharedPreferences(HUB_SECURE_PREFS, Context.MODE_PRIVATE)
        if (value.isBlank()) {
            prefs.edit().remove(key).apply()
            return true
        }
        return runCatching {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateAesKey())
            val iv = cipher.iv
            val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
            val combined = ByteArray(iv.size + encrypted.size)
            System.arraycopy(iv, 0, combined, 0, iv.size)
            System.arraycopy(encrypted, 0, combined, iv.size, encrypted.size)
            prefs.edit().putString(key, Base64.encodeToString(combined, Base64.NO_WRAP)).apply()
            true
        }.getOrDefault(false)
    }

    private fun readSecret(key: String): String {
        if (key.isBlank()) return ""
        val prefs = getSharedPreferences(HUB_SECURE_PREFS, Context.MODE_PRIVATE)
        val encoded = prefs.getString(key, null) ?: return ""
        return runCatching {
            val combined = Base64.decode(encoded, Base64.NO_WRAP)
            if (combined.size <= GCM_IV_LEN) return ""
            val iv = combined.copyOfRange(0, GCM_IV_LEN)
            val ciphertext = combined.copyOfRange(GCM_IV_LEN, combined.size)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateAesKey(), GCMParameterSpec(128, iv))
            String(cipher.doFinal(ciphertext), Charsets.UTF_8)
        }.getOrElse {
            prefs.edit().remove(key).apply()
            ""
        }
    }

    @Deprecated("Uninstall activity result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == UNINSTALL_REQUEST) {
            val (pkg, pending) = pendingUninstall ?: return
            pendingUninstall = null
            pending.success(resultCode == RESULT_OK || !isPackageInstalled(pkg))
        }
    }

    override fun onDestroy() {
        pendingUninstall?.second?.success(false)
        pendingUninstall = null
        worker.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val UNINSTALL_REQUEST = 10
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val HUB_KEY_ALIAS = "icedragon_hub_secrets_v1"
        private const val HUB_SECURE_PREFS = "hub_secure"
        private const val GCM_IV_LEN = 12
    }
}
