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
subprojects {
    project.evaluationDependsOn(":app")
}

// file_picker 11.0.3 pada AGP 9 TIDAK menerapkan plugin Kotlin (mengandalkan
// "built-in Kotlin" AGP 9), sedangkan proyek Flutter ini mematikan built-in
// Kotlin (android.builtInKotlin=false) karena plugin lain (mis. speech_to_text)
// masih menerapkan Kotlin Gradle Plugin sendiri. Akibatnya kode Kotlin
// file_picker tidak dikompilasi ("cannot find symbol FilePickerPlugin").
// Perbaikan: terapkan Kotlin Gradle Plugin khusus untuk proyek file_picker.
subprojects {
    if (name == "file_picker") {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
