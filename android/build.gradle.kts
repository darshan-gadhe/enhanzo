allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Force stale plugins onto a modern compileSdk.
//
// easy_audience_network still declares `compileSdkVersion 28`. Its debug build
// happens to work, but a release build fails resource linking with
// "resource android:attr/lStar not found" — `lStar` arrived in API 31, and a
// module compiled against 28 cannot resolve it in the merged resources of its
// own AndroidX dependencies. Bumping the plugin's compileSdk (not its
// minSdk, so the supported device range is untouched) is what makes
// `flutter build apk --release` link at all.
//
// Must be registered *before* the `evaluationDependsOn(":app")` block below:
// that forces evaluation, and an afterEvaluate hook added afterwards throws
// "project is already evaluated". It also has to run after the plugin's own
// build.gradle, which is the only point at which its compileSdk is readable —
// hence afterEvaluate rather than a plugins.withId hook, which fires too
// early and sees a null value.
subprojects {
    afterEvaluate {
        val ext = project.extensions.findByName("android")
        if (ext is com.android.build.gradle.LibraryExtension) {
            val declared = ext.compileSdkVersion
                ?.removePrefix("android-")
                ?.toIntOrNull()
            if (declared != null && declared < 34) {
                ext.compileSdkVersion(34)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
