import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

val requiredSigningProperties = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
val missingSigningProperties = requiredSigningProperties.filter {
    keystoreProperties.getProperty(it).isNullOrBlank()
}
val configuredKeystoreFile = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let(rootProject::file)
val releaseSigningReady =
    missingSigningProperties.isEmpty() && configuredKeystoreFile?.isFile == true

fun releaseSigningSetupError(): String {
    val details = buildList {
        if (!keystorePropertiesFile.isFile) {
            add("missing ${keystorePropertiesFile.path}")
        }
        if (missingSigningProperties.isNotEmpty()) {
            add("missing properties: ${missingSigningProperties.joinToString()}")
        }
        if (configuredKeystoreFile != null && !configuredKeystoreFile.isFile) {
            add("keystore not found: ${configuredKeystoreFile.path}")
        }
    }.joinToString("; ")

    return "Android release signing is not configured ($details). " +
        "Copy android/key.properties.example to android/key.properties, " +
        "set storeFile, storePassword, keyAlias, and keyPassword, then retry."
}

android {
    namespace = "com.pbcontroller.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pbcontroller.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = configuredKeystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

tasks.configureEach {
    if (name.contains("release", ignoreCase = true) && !releaseSigningReady) {
        doFirst {
            throw GradleException(releaseSigningSetupError())
        }
    }
}

flutter {
    source = "../.."
}
