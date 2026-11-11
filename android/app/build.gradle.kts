import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKey = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun hasValidReleaseSigning(): Boolean {
    if (releaseKey.isEmpty) return false
    val rawStore = releaseKey.getProperty("storeFile")?.trim().orEmpty().removePrefix("../")
    if (rawStore.isEmpty()) return false
    val ksFile = rootProject.file(rawStore)
    return ksFile.exists() &&
        !releaseKey.getProperty("storePassword").isNullOrBlank() &&
        !releaseKey.getProperty("keyAlias").isNullOrBlank() &&
        !releaseKey.getProperty("keyPassword").isNullOrBlank()
}

android {
    namespace = "com.icedragon.apphub"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.icedragon.apphub"
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasValidReleaseSigning()) {
                val rawStore = releaseKey.getProperty("storeFile").trim().removePrefix("../")
                storeFile = rootProject.file(rawStore)
                storePassword = releaseKey.getProperty("storePassword")
                keyAlias = releaseKey.getProperty("keyAlias")
                keyPassword = releaseKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

gradle.taskGraph.whenReady {
    val runningReleaseTask = allTasks.any {
        it.name.contains("Release") &&
            !it.name.contains("UnitTest") &&
            !it.name.contains("AndroidTest")
    }
    if (runningReleaseTask && !hasValidReleaseSigning()) {
        throw GradleException(
            "Release build requires valid android/key.properties and keystore file; debug fallback is disabled.",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
