import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---- Signing release (v1.1.0) -------------------------------------------
// android/key.properties dibuat oleh tool/create_keystore.ps1 (di-ignore git).
// Tanpa keystore, build RELEASE ditolak dengan pesan jelas — kecuali untuk APK
// uji di CI dengan BISINDO_ALLOW_DEBUG_SIGNING=true (ditandatangani debug key).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()
val allowDebugSigning = System.getenv("BISINDO_ALLOW_DEBUG_SIGNING") == "true"

android {
    namespace = "com.example.bisindo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO(K-05): applicationId SEMENTARA — ganti sebelum rilis (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.bisindo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
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

// Tolak build release tanpa keystore (agar tidak diam-diam memakai debug key).
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { it.name.contains("Release") && it.project == project }
    if (buildingRelease && !hasReleaseKeystore && !allowDebugSigning) {
        throw GradleException(
            "Keystore release belum ada (android/key.properties). Jalankan " +
                "'powershell -ExecutionPolicy Bypass -File tool\\create_keystore.ps1' terlebih dahulu. " +
                "Untuk APK uji saja: set BISINDO_ALLOW_DEBUG_SIGNING=true."
        )
    }
}
