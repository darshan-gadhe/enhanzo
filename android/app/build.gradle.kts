import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. key.properties is local-only (gitignored) and holds the
// three secrets plus the keystore's path; the keystore itself lives at the
// repo root, untouched by this file. Missing on a fresh clone that hasn't
// set up signing yet — release builds fail with a clear message below
// instead of a bare NPE deep in the signingConfigs block.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.techneoo.ai.photo.enhancer"
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
        applicationId = "com.techneoo.ai.photo.enhancer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                // rootProject, not the bare file()/project-relative lookup: a
                // bare file() here resolves against this module's own
                // directory (android/app/), one level short of where
                // key.properties' `../upload-keystore.jks` actually points
                // (the repo root, one level above android/ — i.e. rootProject).
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties yet on this checkout — falls back to the
                // debug key so `flutter run --release` still works locally,
                // exactly as the unsigned template did. A Play upload built
                // this way would be rejected at signing verification, not
                // silently accepted with the wrong key.
                signingConfigs.getByName("debug")
            }

            // Meta Audience Network needs explicit R8 rules — its SDK
            // references annotations it doesn't ship, and resolves ad
            // renderers reflectively. See proguard-rules.pro.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Fail a release build that was compiled without --dart-define-from-file=.env.
//
// Those defines are compile-time. Omitting the flag still produces a signed,
// uploadable bundle whose app cannot enhance a single photo — and exactly that
// bundle was installed once, showing users an error where the product should
// have been. Nothing in the build output hinted at it.
//
// Flutter forwards the defines to Gradle as the `dart-defines` property, a
// comma-separated list of base64 `KEY=VALUE` pairs, so the build can check for
// itself that the credentials it needs are actually present. Release tasks
// only: debug and profile are meant to run credential-free on the simulated
// pipeline.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        task.project == project &&
            task.name.contains("Release") &&
            (task.name.startsWith("assemble") || task.name.startsWith("bundle"))
    }
    if (!buildingRelease) return@whenReady

    val defines = (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.mapNotNull { encoded ->
            runCatching { String(Base64.getDecoder().decode(encoded)) }
                .getOrNull()
        }
        ?: emptyList()

    fun supplied(key: String) = defines.any {
        it.startsWith("$key=") && it.substringAfter("=").isNotEmpty()
    }

    if (!supplied("REPLICATE_PROXY_URL") && !supplied("REPLICATE_API_TOKEN")) {
        throw GradleException(
            "Release build is missing Replicate credentials.\n" +
                "REPLICATE_PROXY_URL (or REPLICATE_API_TOKEN) was not compiled in, " +
                "so the app would install and run but could not enhance any photo.\n" +
                "Rebuild with: flutter build appbundle --release --dart-define-from-file=.env"
        )
    }
}

flutter {
    source = "../.."
}
