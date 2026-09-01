import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}
val googleMapsApiKey =
    System.getenv("GOOGLE_MAPS_ANDROID_API_KEY")?.takeIf { it.isNotBlank() }
        ?: localProperties.getProperty("MAPS_API_KEY", "")

// Release credentials stay outside the Android source tree under ignored
// `keys/prod`. CI can mount the same file elsewhere with
// ANDROID_KEY_PROPERTIES / ANDROID_KEYSTORE_PATH.
val releaseKeyPropertiesFile =
    System.getenv("ANDROID_KEY_PROPERTIES")
        ?.takeIf { it.isNotBlank() }
        ?.let(::file)
        ?: projectDir.parentFile.parentFile.resolve("keys/prod/key.properties")
val releaseKeyProperties = Properties().apply {
    if (releaseKeyPropertiesFile.exists()) {
        releaseKeyPropertiesFile.inputStream().use { load(it) }
    }
}
val configuredKeystorePath =
    System.getenv("ANDROID_KEYSTORE_PATH")?.takeIf { it.isNotBlank() }
        ?: releaseKeyProperties.getProperty("storeFile", "")
val releaseKeystoreFile = configuredKeystorePath.takeIf { it.isNotBlank() }?.let { path ->
    val configured = File(path)
    val besideProperties = releaseKeyPropertiesFile.parentFile.resolve(path)
    when {
        configured.isAbsolute -> configured
        besideProperties.exists() -> besideProperties
        else -> releaseKeyPropertiesFile.parentFile.resolve(configured.name)
    }
}
val hasReleaseSigning =
    releaseKeyPropertiesFile.exists() &&
        releaseKeystoreFile?.exists() == true &&
        listOf("storePassword", "keyPassword", "keyAlias").all {
            !releaseKeyProperties.getProperty(it).isNullOrBlank()
        }

android {
    namespace = "com.fixleo.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.fixleo.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseKeyProperties.getProperty("keyAlias")
                keyPassword = releaseKeyProperties.getProperty("keyPassword")
                storeFile = releaseKeystoreFile
                storePassword = releaseKeyProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Never publish a release signed with Flutter's shared debug key.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}
